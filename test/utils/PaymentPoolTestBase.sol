// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ClientToken} from "../../src/ClientToken.sol";
import {PaymentPool} from "../../src/PaymentPool.sol";
import {CLIENT_TOKEN_ID} from "../../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../../src/interfaces/IPaymentPool.sol";
import {Roles} from "../../src/lib/Roles.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {TestMerkle} from "./TestMerkle.sol";

/// @notice Deploys ClientToken and PaymentPool behind ERC-1967 proxies with beta settings, the Safe as admin of
/// both, and PaymentPool holding MINTER_ROLE on ClientToken, as the deployment will.
/// @dev Implementations are deployed from the compiled artifacts with deployCode, not `new`, so their bytecode
/// isn't embedded in every test contract (the 49,152-byte initcode limit). Needs read access to ./out.
abstract contract PaymentPoolTestBase is Test {
    uint256 internal constant T0 = 1_800_000_000;
    /// @dev Beta settings: 5 USDC per 30-day unit, 1 to 12 units, 5 bonus days on 12, 70% to the Network Pool.
    uint256 internal constant PRICE = 5_000_000;
    uint48 internal constant UNIT = 30 days;
    uint16 internal constant MAX_UNITS = 12;
    uint48 internal constant BONUS = 5 days;
    uint16 internal constant SPLIT_BPS = 7000;

    IPaymentPool.Pool internal constant NETWORK = IPaymentPool.Pool.Network;
    IPaymentPool.Pool internal constant BUILDER = IPaymentPool.Pool.Builder;

    address internal safe = makeAddr("safe");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal stranger = makeAddr("stranger");

    MockUSDC internal usdc;
    ClientToken internal token;
    PaymentPool internal pool;

    function setUp() public virtual {
        vm.warp(T0);
        usdc = new MockUSDC();
        token = _deployClientToken(safe);
        pool = _deployPool(safe, address(usdc), address(token));
        vm.prank(safe);
        token.grantRole(Roles.MINTER_ROLE, address(pool));
    }

    // ------------------------------------------------------------------ deployment

    function _deployClientToken(address admin) internal returns (ClientToken) {
        address impl = deployCode("ClientToken.sol:ClientToken");
        return ClientToken(address(new ERC1967Proxy(impl, abi.encodeCall(ClientToken.initialize, (admin, "")))));
    }

    function _deployPool(address admin, address usdc_, address token_) internal returns (PaymentPool) {
        return PaymentPool(address(new ERC1967Proxy(_newPoolImpl(), _initData(admin, usdc_, token_))));
    }

    /// @dev A fresh, uninitialized PaymentPool implementation.
    function _newPoolImpl() internal returns (address) {
        return deployCode("PaymentPool.sol:PaymentPool");
    }

    function _initData(address admin, address usdc_, address token_) internal pure returns (bytes memory) {
        return abi.encodeCall(PaymentPool.initialize, (admin, usdc_, token_, PRICE, UNIT, MAX_UNITS, BONUS, SPLIT_BPS));
    }

    // ------------------------------------------------------------------ money

    /// @dev Mints `amount` test USDC to `who` and approves the pool for everything.
    function _giveUsdc(address who, uint256 amount) internal {
        usdc.mint(who, amount);
        vm.prank(who);
        usdc.approve(address(pool), type(uint256).max);
    }

    /// @dev `who` buys `units` units at the current price, with no referrer.
    function _pay(address who, uint256 units) internal returns (uint48) {
        return _payWithReferrer(who, units, address(0));
    }

    function _payWithReferrer(address who, uint256 units, address referrer) internal returns (uint48) {
        uint256 amount = pool.quote(units);
        _giveUsdc(who, amount);
        vm.prank(who);
        return pool.payForAccess(units, amount, referrer);
    }

    /// @dev Adds `amount` to `p` through fundPool, from a funder wallet.
    function _fund(IPaymentPool.Pool p, uint256 amount) internal {
        address funder = makeAddr("funder");
        _giveUsdc(funder, amount);
        vm.prank(funder);
        pool.fundPool(p, amount);
    }

    // ------------------------------------------------------------------ ledgers and roots

    function _received(IPaymentPool.Pool p) internal view returns (uint256 totalReceived) {
        (, totalReceived,,,) = pool.poolLedger(p);
    }

    function _claimed(IPaymentPool.Pool p) internal view returns (uint256 totalClaimed) {
        (,, totalClaimed,,) = pool.poolLedger(p);
    }

    function _expiry(address who) internal view returns (uint48) {
        return token.expiryOf(who, CLIENT_TOKEN_ID);
    }

    /// @dev Leaves for `accounts` with `amounts` in pool `p`, in that order.
    function _leaves(IPaymentPool.Pool p, address[] memory accounts, uint256[] memory amounts)
        internal
        pure
        returns (bytes32[] memory leaves)
    {
        leaves = new bytes32[](accounts.length);
        for (uint256 i; i < accounts.length; ++i) {
            leaves[i] = TestMerkle.leaf(p, accounts[i], amounts[i]);
        }
    }

    /// @dev Posts the tree of `leaves` for `p` with `total`, for the period ending now.
    function _postRoot(IPaymentPool.Pool p, bytes32[] memory leaves, uint256 total) internal returns (bytes32 root) {
        root = TestMerkle.root(leaves);
        vm.prank(safe);
        pool.setMerkleRoot(p, root, total, uint48(block.timestamp));
    }

    /// @dev Two-account tree for `p`: alice gets `a`, bob gets `b`. Returns the leaves (alice first).
    function _postTwo(IPaymentPool.Pool p, uint256 a, uint256 b) internal returns (bytes32[] memory leaves) {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = a;
        amounts[1] = b;
        leaves = _leaves(p, accounts, amounts);
        _postRoot(p, leaves, a + b);
    }

    function _unauthorized(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role);
    }
}
