// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPaymentPool} from "../../interfaces/IPaymentPool.sol";

/// @title PaymentPoolStorage
/// @notice ERC-7201 namespaced storage for PaymentPool.
/// @dev Fields are only ever appended, never reordered or removed. Pre-mainnet adds the pricing contract
/// address; Phase 2 adds `projectSplitBps`.
library PaymentPoolStorage {
    /// @notice One pool's ledger.
    /// @param root Current Merkle root.
    /// @param totalReceived Everything received, from payments and fundPool.
    /// @param totalClaimed Everything claimed.
    /// @param rootTotal Total cumulative amount of the current root's tree.
    /// @param lastPeriodEnd Period end of the current root.
    struct PoolLedger {
        bytes32 root;
        uint256 totalReceived;
        uint256 totalClaimed;
        uint256 rootTotal;
        uint48 lastPeriodEnd;
    }

    /// @notice A paying wallet's referral record.
    /// @param referrer Recorded on the first payment; zero if none.
    /// @param hasPaid True after the first payment; the referrer can't change after that.
    struct ClientRecord {
        address referrer;
        bool hasPaid;
    }

    /// @custom:storage-location erc7201:skypier.storage.PaymentPool
    struct Layout {
        /// @dev USDC token contract; set once at initialize.
        address usdc;
        /// @dev ClientToken contract; set once at initialize.
        address clientToken;
        /// @dev USDC per unit, in base units.
        uint256 price;
        /// @dev Seconds per unit.
        uint48 unitLength;
        /// @dev Seconds added to a purchase of exactly maxUnits units.
        uint48 fullTermBonus;
        /// @dev Most units per purchase.
        uint16 maxUnits;
        /// @dev Network Pool share in basis points; the Builder Pool takes the rest.
        uint16 networkSplitBps;
        /// @dev Ledger per pool.
        mapping(IPaymentPool.Pool pool => PoolLedger ledger) pools;
        /// @dev Cumulative amount claimed, per pool and account.
        mapping(IPaymentPool.Pool pool => mapping(address account => uint256 amount)) claimed;
        /// @dev Referral record per paying wallet.
        mapping(address client => ClientRecord record) clients;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("skypier.storage.PaymentPool")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant SLOT = 0xa6fc1c7b95c0bed2338093a8bed293bb49976add3eb5b20e3c90ea58a9e14500;

    /// @notice The contract's storage struct.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = SLOT;
        assembly {
            l.slot := slot
        }
    }
}
