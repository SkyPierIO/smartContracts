// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ClientToken} from "../../src/ClientToken.sol";

/// @notice Test-only second version of ClientToken, used to check that an upgrade keeps stored data.
/// @dev Adds one field in its own ERC-7201 namespace, a reinitializer and a version getter. Never deployed.
contract ClientTokenV2Mock is ClientToken {
    /// @custom:storage-location erc7201:skypier.test.ClientTokenV2
    struct V2Layout {
        uint256 marker;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("skypier.test.ClientTokenV2")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant V2_SLOT = 0x4d4d3a117d3c29435e61073a750501a21ffb42fb6121df02b036be60e80a4700;

    /// @notice Runs once, during the upgrade.
    function initializeV2(uint256 marker_) external reinitializer(2) {
        _v2().marker = marker_;
    }

    /// @notice The value set by {initializeV2}.
    function marker() external view returns (uint256) {
        return _v2().marker;
    }

    /// @notice The implementation version.
    function version() external pure returns (uint256) {
        return 2;
    }

    function _v2() private pure returns (V2Layout storage l) {
        bytes32 slot = V2_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

/// @notice A contract with no UUPS support, to check that an upgrade to it is refused.
contract NotUUPS {
    function version() external pure returns (uint256) {
        return 0;
    }
}
