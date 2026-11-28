// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {CLIENT_TOKEN_ID, IClientToken} from "./interfaces/IClientToken.sol";
import {IPaymentPool} from "./interfaces/IPaymentPool.sol";
import {Roles} from "./lib/Roles.sol";
import {PaymentPoolStorage} from "./lib/storage/PaymentPoolStorage.sol";

/// @title PaymentPool
/// @notice Takes USDC for VPN access, splits it between the Network Pool and the Builder Pool, and pays each pool
/// out against the Merkle root the admin Safe posts for it.
/// @dev UUPS upgradeable. All of this contract's own state lives in the ERC-7201 namespace of
/// {PaymentPoolStorage}; roles, pause and the reentrancy flag live in OpenZeppelin's namespaces.
///
/// Rules this implementation keeps on every path:
/// - USDC leaves the contract only through {claim} and {claimMany}, to the caller, and only up to what the caller's
///   leaf allows. There is no sweep or rescue function.
/// - For each pool, totalClaimed <= totalReceived. Every claim checks this, whatever the posted root says.
/// - A pool's root can only release that pool's funds: the leaf includes the pool, and each claim is checked
///   against that pool's root and paid from that pool's ledger.
/// - Payment state (pool ledgers, referral record) is written before USDC is pulled and before ClientToken's mint
///   calls the payer's `onERC1155Received`. {payForAccess}, {fundPool}, {claim} and {claimMany} are
///   `nonReentrant`.
/// - Revenue goes through {_creditPayment}, so later sales functions reuse one split rule.
contract PaymentPool is
    IPaymentPool,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardTransient
{
    using SafeERC20 for IERC20;

    /// @dev Basis points in 100%.
    uint256 private constant BPS = 10_000;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Sets up the proxy: contract addresses, prices and split, and the admin Safe's roles.
    /// @dev The admin gets DEFAULT_ADMIN_ROLE, UPGRADER_ROLE and PAUSER_ROLE. The Safe must then grant this
    /// contract MINTER_ROLE on ClientToken before the first payment. Reverts with {ZeroAddress},
    /// {InvalidClientToken}, {InvalidPricing} or {InvalidSplit}. Emits {PricingUpdated},
    /// {NetworkSplitUpdated} (from 0) and AccessControl's RoleGranted events.
    /// @param admin The admin Safe.
    /// @param usdc_ The USDC token contract; can't be changed later.
    /// @param clientToken_ The ClientToken proxy; can't be changed later.
    /// @param price USDC per unit, in base units.
    /// @param unitLength Seconds per unit.
    /// @param maxUnits Most units in one purchase.
    /// @param fullTermBonus Seconds added to a purchase of exactly `maxUnits` units; at most `unitLength`.
    /// @param networkSplitBps_ The Network Pool's share in basis points.
    function initialize(
        address admin,
        address usdc_,
        address clientToken_,
        uint256 price,
        uint48 unitLength,
        uint16 maxUnits,
        uint48 fullTermBonus,
        uint16 networkSplitBps_
    ) external initializer {
        if (admin == address(0) || usdc_ == address(0) || clientToken_ == address(0)) revert ZeroAddress();
        if (!ERC165Checker.supportsInterface(clientToken_, type(IClientToken).interfaceId)) {
            revert InvalidClientToken(clientToken_);
        }

        __AccessControl_init();
        __Pausable_init();
        _grantRole(Roles.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.UPGRADER_ROLE, admin);
        _grantRole(Roles.PAUSER_ROLE, admin);

        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        l.usdc = usdc_;
        l.clientToken = clientToken_;
        _setPricing(price, unitLength, maxUnits, fullTermBonus);
        _setNetworkSplitBps(networkSplitBps_);
    }

    // ------------------------------------------------------------------ Payments

    /// @inheritdoc IPaymentPool
    /// @dev Order: checks (units, price, expiry cap), then the referral record and pool ledgers, then the USDC
    /// pull, then ClientToken.extendAccess (whose mint may call the payer), then {AccessPurchased}.
    function payForAccess(uint256 units, uint256 maxPayment, address referrer)
        external
        whenNotPaused
        nonReentrant
        returns (uint48 newExpiry)
    {
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        address payer = msg.sender;

        uint256 amount = _price(l, units);
        if (amount > maxPayment) revert PriceAboveMax(amount, maxPayment);
        uint48 duration = _cappedDuration(l, payer, units);
        _recordReferrer(l, payer, referrer);

        (uint256 networkAmount, uint256 builderAmount) = _creditPayment(amount);
        IERC20(l.usdc).safeTransferFrom(payer, address(this), amount);
        newExpiry = IClientToken(l.clientToken).extendAccess(payer, CLIENT_TOKEN_ID, duration);

        emit AccessPurchased(payer, units, amount, networkAmount, builderAmount, newExpiry);
    }

    /// @inheritdoc IPaymentPool
    function fundPool(Pool pool, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        address from = msg.sender;

        l.pools[pool].totalReceived += amount;
        IERC20(l.usdc).safeTransferFrom(from, address(this), amount);
        emit PoolFunded(pool, from, amount);
    }

    // ------------------------------------------------------------------ Payouts

    /// @inheritdoc IPaymentPool
    /// @dev Checks, in order: zero root, total above received, total below claimed, period end before the last,
    /// period end in the future.
    function setMerkleRoot(Pool pool, bytes32 root, uint256 totalCumulative, uint48 periodEnd)
        external
        onlyRole(Roles.DEFAULT_ADMIN_ROLE)
    {
        if (root == bytes32(0)) revert InvalidRoot();
        PaymentPoolStorage.PoolLedger storage ledger = PaymentPoolStorage.layout().pools[pool];

        uint256 received = ledger.totalReceived;
        if (totalCumulative > received) revert TotalExceedsReceived(pool, totalCumulative, received);
        uint256 claimed = ledger.totalClaimed;
        if (totalCumulative < claimed) revert TotalBelowClaimed(pool, totalCumulative, claimed);
        uint48 lastPeriodEnd = ledger.lastPeriodEnd;
        if (periodEnd < lastPeriodEnd) revert PeriodEndBeforeLast(periodEnd, lastPeriodEnd);
        if (periodEnd > block.timestamp) revert PeriodEndInFuture(periodEnd);

        ledger.root = root;
        ledger.rootTotal = totalCumulative;
        ledger.lastPeriodEnd = periodEnd;
        emit MerkleRootSet(pool, root, totalCumulative, periodEnd);
    }

    /// @inheritdoc IPaymentPool
    function claim(Pool pool, uint256 cumulativeAmount, bytes32[] calldata proof)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amount)
    {
        address account = msg.sender;
        amount = _settle(pool, account, cumulativeAmount, proof);
        if (amount == 0) revert NothingToClaim();
        IERC20(PaymentPoolStorage.layout().usdc).safeTransfer(account, amount);
    }

    /// @inheritdoc IPaymentPool
    function claimMany(ClaimRequest[] calldata requests) external whenNotPaused nonReentrant returns (uint256 total) {
        address account = msg.sender;
        uint256 count = requests.length;
        for (uint256 i; i < count; ++i) {
            ClaimRequest calldata r = requests[i];
            total += _settle(r.pool, account, r.cumulativeAmount, r.proof);
        }
        if (total == 0) revert NothingToClaim();
        IERC20(PaymentPoolStorage.layout().usdc).safeTransfer(account, total);
    }

    // ------------------------------------------------------------------ Settings

    /// @inheritdoc IPaymentPool
    function setPricing(uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus)
        external
        onlyRole(Roles.DEFAULT_ADMIN_ROLE)
    {
        _setPricing(price, unitLength, maxUnits, fullTermBonus);
    }

    /// @inheritdoc IPaymentPool
    function setNetworkSplitBps(uint16 bps) external onlyRole(Roles.DEFAULT_ADMIN_ROLE) {
        _setNetworkSplitBps(bps);
    }

    /// @inheritdoc IPaymentPool
    function pause() external onlyRole(Roles.PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc IPaymentPool
    function unpause() external onlyRole(Roles.DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ------------------------------------------------------------------ Views

    /// @inheritdoc IPaymentPool
    function quote(uint256 units) external view returns (uint256 amount) {
        return _price(PaymentPoolStorage.layout(), units);
    }

    /// @inheritdoc IPaymentPool
    function pricing() external view returns (uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus) {
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        return (l.price, l.unitLength, l.maxUnits, l.fullTermBonus);
    }

    /// @inheritdoc IPaymentPool
    function networkSplitBps() external view returns (uint16) {
        return PaymentPoolStorage.layout().networkSplitBps;
    }

    /// @inheritdoc IPaymentPool
    function poolLedger(Pool pool)
        external
        view
        returns (bytes32 root, uint256 totalReceived, uint256 totalClaimed, uint256 rootTotal, uint48 lastPeriodEnd)
    {
        PaymentPoolStorage.PoolLedger storage ledger = PaymentPoolStorage.layout().pools[pool];
        return (ledger.root, ledger.totalReceived, ledger.totalClaimed, ledger.rootTotal, ledger.lastPeriodEnd);
    }

    /// @inheritdoc IPaymentPool
    function claimedOf(Pool pool, address account) external view returns (uint256) {
        return PaymentPoolStorage.layout().claimed[pool][account];
    }

    /// @inheritdoc IPaymentPool
    function referrerOf(address client) external view returns (address) {
        return PaymentPoolStorage.layout().clients[client].referrer;
    }

    /// @inheritdoc IPaymentPool
    function hasPaid(address client) external view returns (bool) {
        return PaymentPoolStorage.layout().clients[client].hasPaid;
    }

    /// @inheritdoc IPaymentPool
    function usdc() external view returns (address) {
        return PaymentPoolStorage.layout().usdc;
    }

    /// @inheritdoc IPaymentPool
    function clientToken() external view returns (address) {
        return PaymentPoolStorage.layout().clientToken;
    }

    // ------------------------------------------------------------------ ERC-165

    /// @notice ERC-165: AccessControl and IPaymentPool.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IPaymentPool).interfaceId || super.supportsInterface(interfaceId);
    }

    // ------------------------------------------------------------------ internal

    /// @dev Only UPGRADER_ROLE (the admin Safe) can upgrade.
    function _authorizeUpgrade(address) internal override onlyRole(Roles.UPGRADER_ROLE) {}

    /// @dev What `units` units cost now. Reverts with {InvalidUnits} unless `units` is 1 to maxUnits.
    function _price(PaymentPoolStorage.Layout storage l, uint256 units) private view returns (uint256) {
        uint256 maxUnits = l.maxUnits;
        if (units == 0 || units > maxUnits) revert InvalidUnits(units, maxUnits);
        return l.price * units;
    }

    /// @dev The time `units` units buy, with the full-term bonus for exactly maxUnits. ClientToken extends from
    /// the later of now and the current expiry, so the cap is checked on the same basis: the new expiry may be at
    /// most (maxUnits + 1) units past now. Reverts with {ExpiryTooFar}. `units` is already checked.
    function _cappedDuration(PaymentPoolStorage.Layout storage l, address payer, uint256 units)
        private
        view
        returns (uint48)
    {
        uint256 maxUnits = l.maxUnits;
        uint256 unitLength = l.unitLength;
        uint256 duration = units * unitLength;
        if (units == maxUnits) duration += l.fullTermBonus;

        uint256 current = IClientToken(l.clientToken).expiryOf(payer, CLIENT_TOKEN_ID);
        uint256 newExpiry = (current > block.timestamp ? current : block.timestamp) + duration;
        uint256 latestAllowed = block.timestamp + (maxUnits + 1) * unitLength;
        if (newExpiry > latestAllowed) revert ExpiryTooFar(newExpiry, latestAllowed);
        return SafeCast.toUint48(duration);
    }

    /// @dev On a wallet's first payment, closes its referral record and stores a non-zero referrer. Reverts with
    /// {SelfReferral} if a first payment names the payer. Later payments change nothing. Emits {ReferrerRecorded}.
    function _recordReferrer(PaymentPoolStorage.Layout storage l, address payer, address referrer) private {
        PaymentPoolStorage.ClientRecord storage client = l.clients[payer];
        if (client.hasPaid) return;
        if (referrer == payer) revert SelfReferral();
        client.hasPaid = true;
        if (referrer != address(0)) {
            client.referrer = referrer;
            emit ReferrerRecorded(payer, referrer);
        }
    }

    /// @dev Splits a client payment between the pools and adds it to their ledgers. The Network Pool gets
    /// `amount` x networkSplitBps / 10_000, rounded down; the Builder Pool gets the rest, including the remainder.
    function _creditPayment(uint256 amount) private returns (uint256 networkAmount, uint256 builderAmount) {
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        networkAmount = amount * l.networkSplitBps / BPS;
        builderAmount = amount - networkAmount;
        l.pools[Pool.Network].totalReceived += networkAmount;
        l.pools[Pool.Builder].totalReceived += builderAmount;
    }

    /// @dev Checks `account`'s leaf against `pool`'s current root and books what is new. Returns 0, changing
    /// nothing, if the account has already claimed `cumulativeAmount` or more. Reverts with {InvalidProof} or
    /// {InsufficientPoolBalance}. Emits {Claimed} when it books something. The caller pays out.
    function _settle(Pool pool, address account, uint256 cumulativeAmount, bytes32[] calldata proof)
        private
        returns (uint256 amount)
    {
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        PaymentPoolStorage.PoolLedger storage ledger = l.pools[pool];

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(uint8(pool), account, cumulativeAmount))));
        if (!MerkleProof.verifyCalldata(proof, ledger.root, leaf)) revert InvalidProof();

        uint256 alreadyClaimed = l.claimed[pool][account];
        if (cumulativeAmount <= alreadyClaimed) return 0;
        amount = cumulativeAmount - alreadyClaimed;

        uint256 claimedTotal = ledger.totalClaimed;
        uint256 available = ledger.totalReceived - claimedTotal;
        if (amount > available) revert InsufficientPoolBalance(pool, amount, available);

        l.claimed[pool][account] = cumulativeAmount;
        ledger.totalClaimed = claimedTotal + amount;
        emit Claimed(pool, account, amount, cumulativeAmount);
    }

    /// @dev Checks and stores the price settings. Reverts with {InvalidPricing}. Emits {PricingUpdated}.
    function _setPricing(uint256 price, uint48 unitLength, uint16 maxUnits, uint48 fullTermBonus) private {
        if (price == 0 || unitLength == 0 || maxUnits == 0 || fullTermBonus > unitLength) revert InvalidPricing();
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        l.price = price;
        l.unitLength = unitLength;
        l.maxUnits = maxUnits;
        l.fullTermBonus = fullTermBonus;
        emit PricingUpdated(price, unitLength, maxUnits, fullTermBonus);
    }

    /// @dev Checks and stores the Network Pool's share. Reverts with {InvalidSplit}. Emits {NetworkSplitUpdated}.
    function _setNetworkSplitBps(uint16 bps) private {
        if (bps > BPS) revert InvalidSplit(bps);
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        emit NetworkSplitUpdated(l.networkSplitBps, bps);
        l.networkSplitBps = bps;
    }
}
