// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ClientTokenStorage
/// @notice ERC-7201 namespaced storage for ClientToken.
/// @dev ERC-1155 balances and the URI live in OpenZeppelin's own namespaces. Fields are only ever appended,
/// never reordered or removed. A subscription freeze (after Phase 2, if built) would append its field here.
library ClientTokenStorage {
    /// @custom:storage-location erc7201:skypier.storage.ClientToken
    struct Layout {
        /// @dev Expiry as a Unix timestamp, per wallet and per token id.
        mapping(address account => mapping(uint256 id => uint48 expiry)) expiry;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("skypier.storage.ClientToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant SLOT = 0xdde10f6e056b1032dbd669df442e3ebe1d310c7978c6be766b673afee9ac1700;

    /// @notice The contract's storage struct.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}
