// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {ClientToken} from "../../src/ClientToken.sol";
import {PaymentPool} from "../../src/PaymentPool.sol";
import {CLIENT_TOKEN_ID} from "../../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../../src/interfaces/IPaymentPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {PaymentPoolTestBase} from "../utils/PaymentPoolTestBase.sol";
import {TestMerkle} from "../utils/TestMerkle.sol";

/// @notice Drives PaymentPool with random payments, top-ups, root postings, claims, pauses and time passing.
/// @dev Roots follow the payout-script rule: each account's cumulative amount only grows, and a tree's total never
/// exceeds what its pool has received. Every expected revert is checked by its error; anything else is counted.
contract PaymentPoolHandler is Test {
    PaymentPool public immutable pool;
    ClientToken public immutable token;
    MockUSDC public immutable usdc;
    address public immutable safe;
    address[] public actors;

    /// @dev Each account's cumulative amount in each pool's current tree.
    mapping(uint8 poolId => mapping(address account => uint256 amount)) public cumulative;
    mapping(uint8 poolId => uint256 total) public treeTotal;
    mapping(uint8 poolId => bool posted) public hasRoot;
    mapping(uint8 poolId => uint256 amount) public fundedInto;

    uint256 public paidIn;
    uint256 public networkFromPayments;
    uint256 public paidOut;
    uint256 public unexpectedReverts;
    uint256 public pausedRefusals;
    uint256 public claims;

    constructor(PaymentPool pool_, ClientToken token_, MockUSDC usdc_, address safe_, address[] memory actors_) {
        pool = pool_;
        token = token_;
        usdc = usdc_;
        safe = safe_;
        actors = actors_;
        for (uint256 i; i < actors_.length; ++i) {
            vm.prank(actors_[i]);
            usdc_.approve(address(pool_), type(uint256).max);
        }
    }

    // ------------------------------------------------------------------ actions

    function pay(uint256 actorSeed, uint256 units) external {
        address actor = _actor(actorSeed);
        (, uint48 unitLength, uint16 maxUnits, uint48 bonus) = pool.pricing();
        units = bound(units, 1, maxUnits);
        uint256 amount = pool.quote(units);
        usdc.mint(actor, amount);

        uint256 current = token.expiryOf(actor, CLIENT_TOKEN_ID);
        uint256 start = current > block.timestamp ? current : block.timestamp;
        uint256 duration = units * unitLength + (units == maxUnits ? bonus : 0);
        bool tooFar = start + duration > block.timestamp + (uint256(maxUnits) + 1) * unitLength;

        vm.prank(actor);
        try pool.payForAccess(units, amount, address(0)) {
            if (tooFar || pool.paused()) unexpectedReverts++; // should have failed
            paidIn += amount;
            networkFromPayments += amount * pool.networkSplitBps() / 10_000;
        } catch (bytes memory reason) {
            if (pool.paused()) {
                _expect(reason, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
                pausedRefusals++;
            } else if (tooFar) {
                bytes4 selector = bytes4(reason);
                if (selector != IPaymentPool.ExpiryTooFar.selector) unexpectedReverts++;
            } else {
                unexpectedReverts++;
            }
            // Unspent test USDC would distort the balance invariants; burn it by sending it to the Safe.
            vm.prank(actor);
            usdc.transfer(safe, amount);
        }
    }

    function fund(uint256 poolSeed, uint256 amount) external {
        uint8 p = uint8(poolSeed % 2);
        amount = bound(amount, 1, 1e12);
        address funder = address(0xF00D);
        usdc.mint(funder, amount);
        vm.startPrank(funder);
        usdc.approve(address(pool), amount);
        pool.fundPool(IPaymentPool.Pool(p), amount); // works paused or not
        vm.stopPrank();
        fundedInto[p] += amount;
    }

    /// @dev Gives part of the pool's unallocated money to one account, rebuilds the tree and posts it.
    function postRoot(uint256 poolSeed, uint256 actorSeed, uint256 extra) external {
        uint8 p = uint8(poolSeed % 2);
        (, uint256 received,,,) = pool.poolLedger(IPaymentPool.Pool(p));
        extra = bound(extra, 0, received - treeTotal[p]);
        cumulative[p][_actor(actorSeed)] += extra;
        treeTotal[p] += extra;

        bytes32[] memory leaves = _leaves(p);
        vm.prank(safe);
        pool.setMerkleRoot(IPaymentPool.Pool(p), TestMerkle.root(leaves), treeTotal[p], uint48(block.timestamp));
        hasRoot[p] = true;
    }

    function claim(uint256 actorSeed, uint256 poolSeed) external {
        uint8 p = uint8(poolSeed % 2);
        if (!hasRoot[p]) return;
        uint256 index = actorSeed % actors.length;
        address actor = actors[index];
        uint256 owed = cumulative[p][actor] - pool.claimedOf(IPaymentPool.Pool(p), actor);
        bytes32[] memory proof = TestMerkle.proof(_leaves(p), index);

        vm.prank(actor);
        try pool.claim(IPaymentPool.Pool(p), cumulative[p][actor], proof) returns (uint256 amount) {
            if (amount != owed || pool.paused()) unexpectedReverts++;
            paidOut += amount;
            claims++;
        } catch (bytes memory reason) {
            if (pool.paused()) {
                _expect(reason, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
                pausedRefusals++;
            } else if (owed == 0) {
                _expect(reason, abi.encodeWithSelector(IPaymentPool.NothingToClaim.selector));
            } else {
                unexpectedReverts++;
            }
        }
    }

    function claimBoth(uint256 actorSeed) external {
        if (!hasRoot[0] || !hasRoot[1]) return;
        uint256 index = actorSeed % actors.length;
        address actor = actors[index];
        IPaymentPool.ClaimRequest[] memory requests = new IPaymentPool.ClaimRequest[](2);
        uint256 owed;
        for (uint8 p; p < 2; ++p) {
            bytes32[] memory proof = TestMerkle.proof(_leaves(p), index);
            requests[p] = IPaymentPool.ClaimRequest(IPaymentPool.Pool(p), cumulative[p][actor], proof);
            owed += cumulative[p][actor] - pool.claimedOf(IPaymentPool.Pool(p), actor);
        }

        vm.prank(actor);
        try pool.claimMany(requests) returns (uint256 total) {
            if (total != owed || pool.paused()) unexpectedReverts++;
            paidOut += total;
            claims++;
        } catch (bytes memory reason) {
            if (pool.paused()) {
                _expect(reason, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
                pausedRefusals++;
            } else if (owed == 0) {
                _expect(reason, abi.encodeWithSelector(IPaymentPool.NothingToClaim.selector));
            } else {
                unexpectedReverts++;
            }
        }
    }

    function togglePause() external {
        vm.prank(safe);
        if (pool.paused()) {
            pool.unpause();
        } else {
            pool.pause();
        }
    }

    function warp(uint256 secondsAhead) external {
        vm.warp(block.timestamp + bound(secondsAhead, 1, 30 days));
    }

    // ------------------------------------------------------------------ helpers

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _leaves(uint8 p) internal view returns (bytes32[] memory leaves) {
        leaves = new bytes32[](actors.length);
        for (uint256 i; i < actors.length; ++i) {
            leaves[i] = TestMerkle.leaf(IPaymentPool.Pool(p), actors[i], cumulative[p][actors[i]]);
        }
    }

    function _expect(bytes memory reason, bytes memory expected) internal {
        if (keccak256(reason) != keccak256(expected)) unexpectedReverts++;
    }
}

/// @notice Money invariants: no pool ever pays out more than it took in, every base unit is accounted for, and
/// nobody is paid beyond their leaf.
contract PaymentPoolInvariantTest is PaymentPoolTestBase {
    PaymentPoolHandler internal handler;
    address[] internal actors;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(carol);
        actors.push(stranger);
        handler = new PaymentPoolHandler(pool, token, usdc, safe, actors);
        targetContract(address(handler));
    }

    /// @dev What each pool paid out never exceeds what it took in.
    function invariant_PoolPaysOutAtMostWhatItReceived() public view {
        for (uint8 p; p < 2; ++p) {
            (, uint256 received, uint256 claimed, uint256 rootTotal,) = pool.poolLedger(IPaymentPool.Pool(p));
            assertLe(claimed, received);
            assertLe(rootTotal, received);
            assertGe(rootTotal, claimed);
        }
    }

    /// @dev The contract holds exactly what the pools still owe; no USDC is created or lost.
    function invariant_BalanceMatchesLedgers() public view {
        uint256 owed;
        uint256 received;
        uint256 claimed;
        for (uint8 p; p < 2; ++p) {
            (, uint256 r, uint256 c,,) = pool.poolLedger(IPaymentPool.Pool(p));
            owed += r - c;
            received += r;
            claimed += c;
        }
        assertEq(usdc.balanceOf(address(pool)), owed);
        assertEq(received, handler.paidIn() + handler.fundedInto(0) + handler.fundedInto(1));
        assertEq(claimed, handler.paidOut());
    }

    /// @dev Each payment is split with the Network Pool's share rounded down and the rest to the Builder Pool.
    function invariant_SplitMatchesPayments() public view {
        assertEq(_received(NETWORK), handler.networkFromPayments() + handler.fundedInto(0));
        assertEq(_received(BUILDER), handler.paidIn() - handler.networkFromPayments() + handler.fundedInto(1));
    }

    /// @dev Nobody is ever paid beyond their leaf, and only claimants receive USDC.
    function invariant_ClaimsWithinLeaves() public view {
        uint256 held;
        for (uint256 i; i < actors.length; ++i) {
            for (uint8 p; p < 2; ++p) {
                assertLe(pool.claimedOf(IPaymentPool.Pool(p), actors[i]), handler.cumulative(p, actors[i]));
            }
            held += usdc.balanceOf(actors[i]);
        }
        assertEq(held, handler.paidOut());
    }

    /// @dev Every revert the handler met was the expected one.
    function invariant_NoUnexpectedReverts() public view {
        assertEq(handler.unexpectedReverts(), 0);
    }
}
