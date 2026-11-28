// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PaymentPool} from "../../src/PaymentPool.sol";

/// @notice Test-only second version of PaymentPool, used to check that an upgrade keeps stored data.
/// @dev Adds one field in its own ERC-7201 namespace, a reinitializer and a version getter. Never deployed.
contract PaymentPoolV2Mock is PaymentPool {
    /// @custom:storage-location erc7201:skypier.test.PaymentPoolV2
    struct V2Layout {
        uint256 marker;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("skypier.test.PaymentPoolV2")) - 1)) & ~bytes32(uint256(0xff)),
    /// computed by script.
    bytes32 internal constant V2_SLOT = 0xab68a423cd6d37fcd219445893c7ca57589034c8348e048a82c0b5b975933900;

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
