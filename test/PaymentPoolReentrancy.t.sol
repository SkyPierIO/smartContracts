// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {CLIENT_TOKEN_ID} from "../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../src/interfaces/IPaymentPool.sol";
import {ReentrantPayer} from "./mocks/ReentrantPayer.sol";
import {PaymentPoolTestBase} from "./utils/PaymentPoolTestBase.sol";
import {TestMerkle} from "./utils/TestMerkle.sol";

/// @notice ClientToken's mint calls the payer during payForAccess. A payer contract can't re-enter PaymentPool
/// then, and by that point the payment is fully recorded.
contract PaymentPoolReentrancyTest is PaymentPoolTestBase {
    ReentrantPayer internal payer;

    function setUp() public override {
        super.setUp();
        payer = new ReentrantPayer(pool, usdc);
        usdc.mint(address(payer), 10 * PRICE);
    }

    function test_Hook_SeesPaymentAlreadyRecorded() public {
        payer.pay(1, PRICE);
        assertTrue(payer.attempted());
        assertEq(payer.networkReceivedDuringHook(), PRICE * SPLIT_BPS / 10_000);
        assertTrue(payer.hasPaidDuringHook());
    }

    function test_Hook_CannotReenterPayForAccess() public {
        payer.setReentry(abi.encodeCall(IPaymentPool.payForAccess, (1, PRICE, address(0))));
        _payAndExpectBlocked();
        assertEq(_received(NETWORK) + _received(BUILDER), PRICE); // only the outer payment
    }

    function test_Hook_CannotReenterFundPool() public {
        payer.setReentry(abi.encodeCall(IPaymentPool.fundPool, (NETWORK, 1)));
        _payAndExpectBlocked();
    }

    /// @dev The payer has a real leaf, so only the guard can stop the claim.
    function test_Hook_CannotReenterClaim() public {
        bytes32[] memory leaves = _postFor(address(payer));
        payer.setReentry(abi.encodeCall(IPaymentPool.claim, (NETWORK, 600_000, TestMerkle.proof(leaves, 0))));
        _payAndExpectBlocked();
        assertEq(pool.claimedOf(NETWORK, address(payer)), 0);
    }

    function test_Hook_CannotReenterClaimMany() public {
        bytes32[] memory leaves = _postFor(address(payer));
        IPaymentPool.ClaimRequest[] memory requests = new IPaymentPool.ClaimRequest[](1);
        requests[0] = IPaymentPool.ClaimRequest(NETWORK, 600_000, TestMerkle.proof(leaves, 0));
        payer.setReentry(abi.encodeCall(IPaymentPool.claimMany, (requests)));
        _payAndExpectBlocked();
        assertEq(pool.claimedOf(NETWORK, address(payer)), 0);
    }

    /// @dev Funds the Network Pool and posts a tree giving `who` 600_000 and alice 400_000.
    function _postFor(address who) private returns (bytes32[] memory leaves) {
        _fund(NETWORK, 1_000_000);
        address[] memory accounts = new address[](2);
        accounts[0] = who;
        accounts[1] = alice;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 600_000;
        amounts[1] = 400_000;
        leaves = _leaves(NETWORK, accounts, amounts);
        _postRoot(NETWORK, leaves, 1_000_000);
    }

    function _payAndExpectBlocked() private {
        uint48 newExpiry = payer.pay(1, PRICE);
        assertEq(newExpiry, uint48(T0) + UNIT);
        assertEq(token.balanceOf(address(payer), CLIENT_TOKEN_ID), 1);
        assertTrue(payer.attempted());
        assertFalse(payer.reentrySucceeded());
        bytes memory expected = abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        assertEq(payer.reentryResult(), expected);
    }
}
