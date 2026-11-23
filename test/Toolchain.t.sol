// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @dev Minimal UUPS contract using the same bases the Core MVP contracts will use.
contract ToolchainProbe is AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}

/// @notice Checks that the compiler, remappings and pinned OpenZeppelin versions work together.
/// Delete once the first real contract and its tests land.
contract ToolchainTest is Test {
    function test_ProxyInitializesAndGrantsAdmin() public {
        address admin = makeAddr("safe");
        ToolchainProbe impl = new ToolchainProbe();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ToolchainProbe.initialize, (admin)));
        ToolchainProbe probe = ToolchainProbe(address(proxy));

        assertTrue(probe.hasRole(probe.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(probe.hasRole(probe.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    function test_ImplementationCannotBeInitialized() public {
        ToolchainProbe impl = new ToolchainProbe();
        vm.expectRevert();
        impl.initialize(address(this));
    }

    function test_MerkleSingleLeaf() public pure {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(address(1), uint256(100)))));
        bytes32[] memory proof = new bytes32[](0);
        assertTrue(MerkleProof.verify(proof, leaf, leaf));
    }
}
