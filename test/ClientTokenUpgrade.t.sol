// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ClientToken} from "../src/ClientToken.sol";
import {CLIENT_TOKEN_ID} from "../src/interfaces/IClientToken.sol";
import {Roles} from "../src/lib/Roles.sol";
import {ClientTokenStorage} from "../src/lib/storage/ClientTokenStorage.sol";
import {ClientTokenTestBase} from "./utils/ClientTokenTestBase.sol";
import {ClientTokenV2Mock, NotUUPS} from "./mocks/ClientTokenV2Mock.sol";

/// @notice Deploys through a proxy, upgrades to a test version, and checks that stored data survives.
/// Replaces test/Toolchain.t.sol.
contract ClientTokenUpgradeTest is ClientTokenTestBase {
    /// @dev Fixed wallets so their storage slots can be computed off-chain.
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    /// @dev keccak256(abi.encode(1, keccak256(abi.encode(0xA11CE, ClientTokenStorage.SLOT)))), computed by script:
    /// the slot of expiry[ALICE][CLIENT_TOKEN_ID].
    bytes32 internal constant ALICE_EXPIRY_SLOT = 0x44a34e645ba9e9f0c23a87c440c28b551354157564e1053febc7a771901a289f;
    /// @dev The same for 0xB0B.
    bytes32 internal constant BOB_EXPIRY_SLOT = 0x37930451ebeb19c639d04b12aa5bbe3e120b87e6bd9840045406fa15c95e43ef;
    /// @dev keccak256(abi.encode(uint256(keccak256("eip1967.proxy.implementation")) - 1)), computed by script.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    string internal constant URI_1 = "test://client-token/v1-set/{id}.json";

    function _populate() internal returns (uint48 aliceExpiry, uint48 bobExpiry) {
        _extend(ALICE, 3 * UNIT);
        _extend(BOB, UNIT);
        _extend(alice, UNIT);
        _adminTransfer(alice, bob); // bob receives alice's token
        _extend(stranger, UNIT);
        vm.prank(stranger);
        token.burnClientToken();
        vm.prank(safe);
        token.setURI(URI_1);
        return (_expiry(ALICE), _expiry(BOB));
    }

    function test_ExpirySlotsMatchFormula() public pure {
        bytes32 inner = keccak256(abi.encode(ALICE, ClientTokenStorage.SLOT));
        assertEq(keccak256(abi.encode(CLIENT_TOKEN_ID, inner)), ALICE_EXPIRY_SLOT);
        inner = keccak256(abi.encode(BOB, ClientTokenStorage.SLOT));
        assertEq(keccak256(abi.encode(CLIENT_TOKEN_ID, inner)), BOB_EXPIRY_SLOT);
        assertEq(ERC1967Utils.IMPLEMENTATION_SLOT, IMPLEMENTATION_SLOT);
    }

    function test_ExpiryStoredAtNamespacedSlot() public {
        (uint48 aliceExpiry, uint48 bobExpiry) = _populate();
        assertEq(uint256(vm.load(address(token), ALICE_EXPIRY_SLOT)), aliceExpiry);
        assertEq(uint256(vm.load(address(token), BOB_EXPIRY_SLOT)), bobExpiry);
    }

    function test_Upgrade_KeepsStoredData() public {
        (uint48 aliceExpiry, uint48 bobExpiry) = _populate();
        uint48 bobsExpiry = _expiry(bob);
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();

        vm.expectEmit(true, false, false, false, address(token));
        emit IERC1967.Upgraded(address(v2));
        vm.prank(safe);
        token.upgradeToAndCall(address(v2), abi.encodeCall(ClientTokenV2Mock.initializeV2, (42)));

        ClientTokenV2Mock upgraded = ClientTokenV2Mock(address(token));
        assertEq(vm.load(address(token), IMPLEMENTATION_SLOT), bytes32(uint256(uint160(address(v2)))));
        assertEq(upgraded.version(), 2);
        assertEq(upgraded.marker(), 42);

        // Expiries, raw slots, balances, URI and roles are unchanged.
        assertEq(upgraded.expiryOf(ALICE, CLIENT_TOKEN_ID), aliceExpiry);
        assertEq(upgraded.expiryOf(BOB, CLIENT_TOKEN_ID), bobExpiry);
        assertEq(uint256(vm.load(address(token), ALICE_EXPIRY_SLOT)), aliceExpiry);
        assertEq(uint256(vm.load(address(token), BOB_EXPIRY_SLOT)), bobExpiry);
        assertEq(upgraded.expiryOf(bob, CLIENT_TOKEN_ID), bobsExpiry);
        assertEq(upgraded.expiryOf(alice, CLIENT_TOKEN_ID), 0);
        assertEq(upgraded.expiryOf(stranger, CLIENT_TOKEN_ID), 0);
        assertEq(upgraded.balanceOf(ALICE, CLIENT_TOKEN_ID), 1);
        assertEq(upgraded.balanceOf(bob, CLIENT_TOKEN_ID), 1);
        assertEq(upgraded.balanceOf(alice, CLIENT_TOKEN_ID), 0);
        assertEq(upgraded.balanceOf(stranger, CLIENT_TOKEN_ID), 0);
        assertTrue(upgraded.isValid(ALICE, CLIENT_TOKEN_ID));
        assertTrue(upgraded.isValid(bob, CLIENT_TOKEN_ID));
        assertEq(upgraded.uri(CLIENT_TOKEN_ID), URI_1);
        assertTrue(upgraded.hasRole(Roles.DEFAULT_ADMIN_ROLE, safe));
        assertTrue(upgraded.hasRole(Roles.UPGRADER_ROLE, safe));
        assertTrue(upgraded.hasRole(Roles.MINTER_ROLE, minter));

        // The upgraded contract still works.
        _extend(ALICE, UNIT);
        assertEq(upgraded.expiryOf(ALICE, CLIENT_TOKEN_ID), aliceExpiry + UNIT);
    }

    function test_Upgrade_ReinitializerRunsOnce() public {
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();
        vm.prank(safe);
        token.upgradeToAndCall(address(v2), abi.encodeCall(ClientTokenV2Mock.initializeV2, (1)));
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ClientTokenV2Mock(address(token)).initializeV2(2);
    }

    function test_Upgrade_RevertsForStranger() public {
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.UPGRADER_ROLE));
        token.upgradeToAndCall(address(v2), "");
    }

    /// @dev Upgrading needs UPGRADER_ROLE itself; DEFAULT_ADMIN_ROLE alone is not enough.
    function test_Upgrade_RevertsForAdminWithoutUpgraderRole() public {
        address adminOnly = makeAddr("adminOnly");
        vm.startPrank(safe);
        token.grantRole(Roles.DEFAULT_ADMIN_ROLE, adminOnly);
        vm.stopPrank();
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();
        vm.prank(adminOnly);
        vm.expectRevert(_unauthorized(adminOnly, Roles.UPGRADER_ROLE));
        token.upgradeToAndCall(address(v2), "");
    }

    function test_Upgrade_RevertsForMinter() public {
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();
        vm.prank(minter);
        vm.expectRevert(_unauthorized(minter, Roles.UPGRADER_ROLE));
        token.upgradeToAndCall(address(v2), "");
    }

    function test_Upgrade_RevertsForNonUUPSImplementation() public {
        NotUUPS bad = new NotUUPS();
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(bad)));
        token.upgradeToAndCall(address(bad), "");
    }

    function test_Upgrade_CannotBeCalledOnImplementation() public {
        ClientToken impl = new ClientToken();
        ClientTokenV2Mock v2 = new ClientTokenV2Mock();
        vm.expectRevert(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector);
        impl.upgradeToAndCall(address(v2), "");
    }
}
