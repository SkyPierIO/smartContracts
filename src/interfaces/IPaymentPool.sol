// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IPaymentPool
/// @notice Takes USDC payments for VPN access, splits them between two pools, and pays out from each pool
/// against a Merkle root the admin Safe posts every two weeks.
/// @dev PaymentPool also implements AccessControl and Pausable; their functions are not repeated here.
///
/// Money rules:
/// - A unit is `unitLength` seconds (30 days). A purchase is 1 to `maxUnits` units (12) at `price` per unit
///   (beta: 5 USDC = 5_000_000 base units). Buying exactly `maxUnits` units adds `fullTermBonus` seconds
///   (5 days), so 12 units cover 365 days.
/// - A purchase can't push the buyer's expiry more than (`maxUnits` + 1) x `unitLength` past now (390 days).
/// - Split: networkShare = amount x `networkSplitBps` / 10_000, rounded down; builderShare = amount -
///   networkShare, so the Builder Pool takes the rounding remainder.
/// - Each pool has its own balance, root and claims. A pool can never pay out more than it has received.
///
/// Merkle leaf, one tree per pool (OpenZeppelin StandardMerkleTree, types ["uint8","address","uint256"]):
///   leaf = keccak256(bytes.concat(keccak256(abi.encode(uint8(pool), account, cumulativeAmount))))
/// `cumulativeAmount` is everything the account has earned from that pool since launch, in USDC base units.
/// A claim pays the difference between it and what the account has already claimed from that pool.
///
/// Referrals: the first {payForAccess} by a wallet records its referrer once. A zero referrer there means
/// none, permanently; referrers passed on later payments are ignored. Rewards are computed off-chain later
/// (only mainnet referrals whose first purchase is 3 units or more earn them), so nothing is paid here.
///
/// Pause stops {payForAccess}, {fundPool} and {claim}. Root posting and settings still work while paused.
interface IPaymentPool {
    /// @notice The two payout pools. Values are fixed: Network = 0, Builder = 1.
    enum Pool {
        Network,
        Builder
    }

    /// @notice A client paid for access.
    /// @param payer The wallet that paid and received access.
    /// @param units Units bought.
    /// @param amount USDC paid, in base units.
    /// @param networkAmount Part of `amount` added to the Network Pool.
    /// @param builderAmount Part of `amount` added to the Builder Pool, including the rounding remainder.
    /// @param newExpiry The payer's Client token expiry after the purchase.
    event AccessPurchased(
        address indexed payer,
        uint256 units,
        uint256 amount,
        uint256 networkAmount,
        uint256 builderAmount,
        uint48 newExpiry
    );

    /// @notice A client's referrer was recorded, on the client's first payment.
    event ReferrerRecorded(address indexed client, address indexed referrer);

    /// @notice USDC was added to a pool outside a client payment. Pool income, not revenue.
    event PoolFunded(Pool indexed pool, address indexed from, uint256 amount);

    /// @notice The admin Safe posted a new Merkle root for a pool.
    /// @param pool The pool the root pays from.
    /// @param root The new root.
    /// @param totalCumulative Sum of all leaves' cumulative amounts in the tree.
    /// @param periodEnd End of the payout period the tree covers, as a Unix timestamp.
    event MerkleRootSet(Pool indexed pool, bytes32 root, uint256 totalCumulative, uint48 periodEnd);

    /// @notice An account claimed from a pool.
    /// @param pool The pool paid from.
    /// @param account The account paid; always the caller.
    /// @param amount USDC paid by this claim.
    /// @param cumulativeClaimed Everything the account has claimed from this pool so far.
    event Claimed(Pool indexed pool, address indexed account, uint256 amount, uint256 cumulativeClaimed);

    /// @notice The admin Safe changed the price settings.
    event PricingUpdated(uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus);

    /// @notice The admin Safe changed the Network Pool's share.
    event NetworkSplitUpdated(uint16 oldBps, uint16 newBps);

    /// @notice `units` is 0 or above `maxUnits`.
    error InvalidUnits(uint256 units, uint256 maxUnits);

    /// @notice The purchase would cost more than the buyer's `maxPayment`.
    error PriceAboveMax(uint256 amount, uint256 maxPayment);

    /// @notice The purchase would push the expiry past the furthest allowed date.
    error ExpiryTooFar(uint256 newExpiry, uint256 latestAllowed);

    /// @notice A wallet named itself as referrer on its first payment.
    error SelfReferral();

    /// @notice An amount argument was zero.
    error ZeroAmount();

    /// @notice An address argument was the zero address.
    error ZeroAddress();

    /// @notice A price setting was zero: price, unit length or max units.
    error InvalidPricing();

    /// @notice The split is above 10_000 basis points.
    error InvalidSplit(uint256 bps);

    /// @notice The root was zero.
    error InvalidRoot();

    /// @notice The tree's total is more than the pool has ever received.
    error TotalExceedsReceived(Pool pool, uint256 totalCumulative, uint256 totalReceived);

    /// @notice The period end is earlier than the last root's period end.
    error PeriodEndBeforeLast(uint48 periodEnd, uint48 lastPeriodEnd);

    /// @notice The period end is in the future.
    error PeriodEndInFuture(uint48 periodEnd);

    /// @notice The Merkle proof doesn't match the pool's current root.
    error InvalidProof();

    /// @notice The account has already claimed everything in its leaf.
    error NothingToClaim();

    /// @notice The claim would take the pool below zero. Should be unreachable given the root total check.
    error InsufficientPoolBalance(Pool pool, uint256 requested, uint256 available);

    /// @notice Buys access for the caller at the current price, and records their referrer on their first
    /// payment.
    /// @dev Pulls `price` x `units` USDC from the caller (approve first), splits it between the pools, then
    /// calls ClientToken.extendAccess for the caller. Reverts with {InvalidUnits}, {PriceAboveMax},
    /// {ExpiryTooFar} or, on a first payment naming the caller, {SelfReferral}. Not while paused.
    /// Emits {AccessPurchased}, and {ReferrerRecorded} on a first payment with a non-zero referrer.
    /// @param units Units to buy, 1 to `maxUnits`.
    /// @param maxPayment Most the caller agrees to pay, in USDC base units, so a price change can't
    /// overcharge them.
    /// @param referrer Who referred the caller; zero for none. Only read on the caller's first payment.
    /// @return newExpiry The caller's Client token expiry after the purchase.
    function payForAccess(uint256 units, uint256 maxPayment, address referrer) external returns (uint48 newExpiry);

    /// @notice Adds USDC to a pool, for example a Safe top-up of the Builder Pool or testnet seeding.
    /// @dev Anyone can call. Pulls `amount` USDC from the caller (approve first). It only adds money.
    /// Not while paused. Emits {PoolFunded}.
    /// @param pool The pool to fund.
    /// @param amount USDC to add, in base units; must be positive.
    function fundPool(Pool pool, uint256 amount) external;

    /// @notice Posts a pool's Merkle root for a payout period.
    /// @dev Only DEFAULT_ADMIN_ROLE (the admin Safe). Works while paused. Reverts with {InvalidRoot},
    /// {TotalExceedsReceived}, {PeriodEndBeforeLast} or {PeriodEndInFuture}. Re-posting the same period end
    /// is allowed, for corrections. Emits {MerkleRootSet}.
    /// @param pool The pool the root pays from.
    /// @param root The tree's root; leaf format in the contract notes above.
    /// @param totalCumulative Sum of every leaf's cumulative amount; must not exceed what the pool has
    /// received.
    /// @param periodEnd End of the payout period the tree covers.
    function setMerkleRoot(Pool pool, bytes32 root, uint256 totalCumulative, uint48 periodEnd) external;

    /// @notice Claims the caller's unpaid earnings from a pool. Pays the caller only.
    /// @dev Reverts with {InvalidProof}, {NothingToClaim} or {InsufficientPoolBalance}. Not while paused.
    /// Emits {Claimed}.
    /// @param pool The pool to claim from.
    /// @param cumulativeAmount The caller's cumulative amount in the pool's current tree.
    /// @param proof Merkle proof of the caller's leaf.
    /// @return amount USDC paid by this claim.
    function claim(Pool pool, uint256 cumulativeAmount, bytes32[] calldata proof) external returns (uint256 amount);

    /// @notice Changes the price settings. Applies to purchases from the next transaction on.
    /// @dev Only DEFAULT_ADMIN_ROLE. Reverts with {InvalidPricing} if `price`, `unitLength` or `maxUnits` is 0.
    /// `fullTermBonus` may be 0. Emits {PricingUpdated}.
    /// @param price USDC per unit, in base units.
    /// @param unitLength Seconds per unit.
    /// @param maxUnits Most units in one purchase; the bonus applies to purchases of exactly this many.
    /// @param fullTermBonus Seconds added to a purchase of `maxUnits` units.
    function setPricing(uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus) external;

    /// @notice Changes the Network Pool's share of each payment. The Builder Pool gets the rest.
    /// @dev Only DEFAULT_ADMIN_ROLE. Reverts with {InvalidSplit} above 10_000. Emits {NetworkSplitUpdated}.
    /// @param bps The Network Pool's share in basis points (7000 = 70%).
    function setNetworkSplitBps(uint16 bps) external;

    /// @notice Pauses payments, pool funding and claims.
    /// @dev Only PAUSER_ROLE. Emits Pausable's Paused.
    function pause() external;

    /// @notice Ends a pause.
    /// @dev Only DEFAULT_ADMIN_ROLE (the admin Safe). Emits Pausable's Unpaused.
    function unpause() external;

    /// @notice What `units` units cost now, in USDC base units.
    function quote(uint256 units) external view returns (uint256 amount);

    /// @notice The current price settings.
    function pricing() external view returns (uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus);

    /// @notice The Network Pool's share of each payment, in basis points.
    function networkSplitBps() external view returns (uint16);

    /// @notice A pool's ledger.
    /// @return root The current Merkle root.
    /// @return totalReceived Everything the pool has received, from payments and {fundPool}.
    /// @return totalClaimed Everything claimed from the pool.
    /// @return rootTotal The current root's total cumulative amount.
    /// @return lastPeriodEnd The current root's period end.
    function poolLedger(Pool pool)
        external
        view
        returns (bytes32 root, uint256 totalReceived, uint256 totalClaimed, uint256 rootTotal, uint48 lastPeriodEnd);

    /// @notice Everything `account` has claimed from `pool` so far.
    function claimedOf(Pool pool, address account) external view returns (uint256);

    /// @notice The referrer recorded for a client; zero if none.
    function referrerOf(address client) external view returns (address);

    /// @notice Whether the wallet has ever paid, which closes its referrer record.
    function hasPaid(address client) external view returns (bool);

    /// @notice The USDC token contract.
    function usdc() external view returns (address);

    /// @notice The ClientToken contract.
    function clientToken() external view returns (address);
}
