// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISkypierVPN} from "../../interfaces/ISkypierVPN.sol";

/// @title SkypierVPNStorage
/// @notice ERC-7201 namespaced storage for SkypierVPN.
/// @dev Fields are only ever appended, never reordered or removed. Item 11 may add the node key's address;
/// Pre-mainnet adds validator status and the ValidatorEscrow address.
library SkypierVPNStorage {
    /// @notice An operator's registration record.
    /// @param referrer Recorded at the first registration; zero if none.
    /// @param registered True after the first registration; the referrer can't change after that.
    struct OperatorRecord {
        address referrer;
        bool registered;
    }

    /// @custom:storage-location erc7201:skypier.storage.SkypierVPN
    struct Layout {
        /// @dev Node record by keccak256 of the binary PeerID.
        mapping(bytes32 nodeId => ISkypierVPN.Node node) nodes;
        /// @dev Number of Validated nodes per operator, whether or not it is whitelisted.
        mapping(address operator => uint256 count) validatedNodeCount;
        /// @dev Registration record per operator.
        mapping(address operator => OperatorRecord record) operators;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("skypier.storage.SkypierVPN")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant SLOT = 0xb49130c08145230db30d4d2b78e57d52f73468973853feb0bf0e97ed38412c00;

    /// @notice The contract's storage struct.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}
