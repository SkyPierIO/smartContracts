// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {PaymentPool} from "../src/PaymentPool.sol";
import {Roles} from "../src/lib/Roles.sol";
import {PaymentPoolStorage} from "../src/lib/storage/PaymentPoolStorage.sol";
import {NotUUPS} from "./mocks/ClientTokenV2Mock.sol";
import {PaymentPoolV2Mock} from "./mocks/PaymentPoolV2Mock.sol";
import {PaymentPoolTestBase} from "./utils/PaymentPoolTestBase.sol";
import {TestMerkle} from "./utils/TestMerkle.sol";

/// @notice Storage positions, and an upgrade that keeps every ledger, claim and referral record.
contract PaymentPoolUpgradeTest is PaymentPoolTestBase {
    /// @dev A fixed wallet so its storage slots can be computed off-chain.
    address internal constant ALICE = address(0xA11CE);

    /// @dev keccak256(abi.encode(0, SLOT + 4)), computed by script: the Network Pool's PoolLedger.
    bytes32 internal constant NETWORK_LEDGER_SLOT = 0x730cb1976bbd86e26ff7d0c0e4071049d0984059ac9167e6a8819571d546c673;
    /// @dev keccak256(abi.encode(1, SLOT + 4)), computed by script: the Builder Pool's PoolLedger.
    bytes32 internal constant BUILDER_LEDGER_SLOT = 0x76ac9024e0fd0a54b26c2557d7c27011cca69cfbdab197335e15fdb9401a4b05;
    /// @dev keccak256(abi.encode(0xA11CE, keccak256(abi.encode(0, SLOT + 5)))), computed by script:
    /// claimed[Network][ALICE].
    bytes32 internal constant ALICE_NETWORK_CLAIMED_SLOT =
        0x3174a8222b17e16219aac77b8c06e59184e12ebca56409e3ceefdbd53f27178a;
    /// @dev keccak256(abi.encode(0xA11CE, SLOT + 6)), computed by script: clients[ALICE].
    bytes32 internal constant ALICE_CLIENT_SLOT = 0x55d5969329e0ff638b0a2beaf56210e24e1f65364de15f720bd1cfcd7c26365c;

    bytes32 internal networkRoot;

    function _populate() internal {
        _payWithReferrer(ALICE, 3, bob); // Network 10_500_000, Builder 4_500_000
        _fund(BUILDER, 1_000_000);
        address[] memory accounts = new address[](2);
        accounts[0] = ALICE;
        accounts[1] = carol;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 7_000_000;
        amounts[1] = 3_000_000;
        bytes32[] memory leaves = _leaves(NETWORK, accounts, amounts);
        networkRoot = _postRoot(NETWORK, leaves, 10_000_000);
        vm.prank(ALICE);
        pool.claim(NETWORK, 7_000_000, TestMerkle.proof(leaves, 0));
        vm.prank(safe);
        pool.setNetworkSplitBps(6500);
    }

    function test_SlotsMatchFormula() public pure {
        uint256 base = uint256(PaymentPoolStorage.SLOT);
        assertEq(keccak256(abi.encode(uint256(0), base + 4)), NETWORK_LEDGER_SLOT);
        assertEq(keccak256(abi.encode(uint256(1), base + 4)), BUILDER_LEDGER_SLOT);
        bytes32 inner = keccak256(abi.encode(uint256(0), base + 5));
        assertEq(keccak256(abi.encode(ALICE, inner)), ALICE_NETWORK_CLAIMED_SLOT);
        assertEq(keccak256(abi.encode(ALICE, base + 6)), ALICE_CLIENT_SLOT);
    }

    function test_StateStoredAtNamespacedSlots() public {
        _populate();
        _assertRawSlots(address(pool));
    }

    function test_Upgrade_KeepsStoredData() public {
        _populate();
        PaymentPoolV2Mock v2 = _newV2();

        vm.expectEmit(true, false, false, false, address(pool));
        emit IERC1967.Upgraded(address(v2));
        vm.prank(safe);
        pool.upgradeToAndCall(address(v2), abi.encodeCall(PaymentPoolV2Mock.initializeV2, (42)));

        PaymentPoolV2Mock upgraded = PaymentPoolV2Mock(address(pool));
        assertEq(vm.load(address(pool), ERC1967Utils.IMPLEMENTATION_SLOT), bytes32(uint256(uint160(address(v2)))));
        assertEq(upgraded.version(), 2);
        assertEq(upgraded.marker(), 42);

        _assertRawSlots(address(pool));
        (bytes32 root, uint256 received, uint256 claimed, uint256 rootTotal,) = upgraded.poolLedger(NETWORK);
        assertEq(root, networkRoot);
        assertEq(received, 10_500_000);
        assertEq(claimed, 7_000_000);
        assertEq(rootTotal, 10_000_000);
        assertEq(_received(BUILDER), 5_500_000);
        assertEq(upgraded.claimedOf(NETWORK, ALICE), 7_000_000);
        assertEq(upgraded.referrerOf(ALICE), bob);
        assertTrue(upgraded.hasPaid(ALICE));
        assertEq(upgraded.networkSplitBps(), 6500);
        assertEq(upgraded.usdc(), address(usdc));
        assertEq(upgraded.clientToken(), address(token));
        assertTrue(upgraded.hasRole(Roles.DEFAULT_ADMIN_ROLE, safe));
        assertTrue(upgraded.hasRole(Roles.UPGRADER_ROLE, safe));
        assertTrue(upgraded.hasRole(Roles.PAUSER_ROLE, safe));
        assertEq(usdc.balanceOf(address(pool)), 16_000_000 - 7_000_000);

        // The upgraded contract still takes payments with the new split.
        _pay(carol, 1);
        assertEq(_received(NETWORK), 10_500_000 + 3_250_000);
    }

    function test_Upgrade_ReinitializerRunsOnce() public {
        PaymentPoolV2Mock v2 = _newV2();
        vm.prank(safe);
        pool.upgradeToAndCall(address(v2), abi.encodeCall(PaymentPoolV2Mock.initializeV2, (1)));
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        PaymentPoolV2Mock(address(pool)).initializeV2(2);
    }

    function test_Upgrade_RevertsForStranger() public {
        address v2 = address(_newV2());
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.UPGRADER_ROLE));
        pool.upgradeToAndCall(v2, "");
    }

    /// @dev Upgrading needs UPGRADER_ROLE itself; DEFAULT_ADMIN_ROLE or PAUSER_ROLE alone is not enough.
    function test_Upgrade_RevertsForAdminOrPauserWithoutUpgraderRole() public {
        address adminOnly = makeAddr("adminOnly");
        address pauserOnly = makeAddr("pauserOnly");
        vm.startPrank(safe);
        pool.grantRole(Roles.DEFAULT_ADMIN_ROLE, adminOnly);
        pool.grantRole(Roles.PAUSER_ROLE, pauserOnly);
        vm.stopPrank();
        address v2 = address(_newV2());

        vm.prank(adminOnly);
        vm.expectRevert(_unauthorized(adminOnly, Roles.UPGRADER_ROLE));
        pool.upgradeToAndCall(v2, "");
        vm.prank(pauserOnly);
        vm.expectRevert(_unauthorized(pauserOnly, Roles.UPGRADER_ROLE));
        pool.upgradeToAndCall(v2, "");
    }

    function test_Upgrade_RevertsForNonUUPSImplementation() public {
        NotUUPS bad = new NotUUPS();
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(bad)));
        pool.upgradeToAndCall(address(bad), "");
    }

    function test_Upgrade_CannotBeCalledOnImplementation() public {
        PaymentPool impl = PaymentPool(_newPoolImpl());
        address v2 = address(_newV2());
        vm.expectRevert(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector);
        impl.upgradeToAndCall(v2, "");
    }

    function _newV2() private returns (PaymentPoolV2Mock) {
        return PaymentPoolV2Mock(deployCode("PaymentPoolV2Mock.sol:PaymentPoolV2Mock"));
    }

    /// @dev Reads the namespaced slots directly, so a field moved inside the Layout struct fails here.
    function _assertRawSlots(address target) private view {
        bytes32 base = PaymentPoolStorage.SLOT;
        assertEq(vm.load(target, base), bytes32(uint256(uint160(address(usdc)))));
        assertEq(vm.load(target, bytes32(uint256(base) + 1)), bytes32(uint256(uint160(address(token)))));
        assertEq(uint256(vm.load(target, bytes32(uint256(base) + 2))), PRICE);
        // unitLength, fullTermBonus, maxUnits and networkSplitBps share one slot, in declaration order.
        uint256 packed = uint256(UNIT) | uint256(BONUS) << 48 | uint256(MAX_UNITS) << 96 | uint256(6500) << 112;
        assertEq(uint256(vm.load(target, bytes32(uint256(base) + 3))), packed);

        assertEq(vm.load(target, NETWORK_LEDGER_SLOT), networkRoot);
        assertEq(uint256(vm.load(target, bytes32(uint256(NETWORK_LEDGER_SLOT) + 1))), 10_500_000);
        assertEq(uint256(vm.load(target, bytes32(uint256(NETWORK_LEDGER_SLOT) + 2))), 7_000_000);
        assertEq(uint256(vm.load(target, bytes32(uint256(NETWORK_LEDGER_SLOT) + 3))), 10_000_000);
        assertEq(uint256(vm.load(target, bytes32(uint256(NETWORK_LEDGER_SLOT) + 4))), T0);
        assertEq(uint256(vm.load(target, bytes32(uint256(BUILDER_LEDGER_SLOT) + 1))), 5_500_000);

        assertEq(uint256(vm.load(target, ALICE_NETWORK_CLAIMED_SLOT)), 7_000_000);
        // ClientRecord: referrer in the low 20 bytes, hasPaid in the next byte.
        assertEq(uint256(vm.load(target, ALICE_CLIENT_SLOT)), uint256(uint160(bob)) | uint256(1) << 160);
    }
}
