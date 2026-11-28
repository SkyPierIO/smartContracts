// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IERC20Errors, IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {CLIENT_TOKEN_ID, IClientToken} from "../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../src/interfaces/IPaymentPool.sol";
import {Roles} from "../src/lib/Roles.sol";
import {NonReceiver} from "./mocks/ERC1155ReceiverMocks.sol";
import {PaymentPoolTestBase} from "./utils/PaymentPoolTestBase.sol";

/// @notice payForAccess and fundPool.
contract PaymentPoolPayTest is PaymentPoolTestBase {
    // ------------------------------------------------------------------ payForAccess: success

    function test_Pay_OneUnit() public {
        _giveUsdc(alice, PRICE);
        uint256 network = PRICE * SPLIT_BPS / 10_000;

        vm.expectEmit(address(token));
        emit IClientToken.AccessExtended(alice, CLIENT_TOKEN_ID, uint48(T0) + UNIT);
        vm.expectEmit(address(pool));
        emit IPaymentPool.AccessPurchased(alice, 1, PRICE, network, PRICE - network, uint48(T0) + UNIT);
        vm.prank(alice);
        uint48 newExpiry = pool.payForAccess(1, PRICE, address(0));

        assertEq(newExpiry, uint48(T0) + UNIT);
        assertEq(_expiry(alice), newExpiry);
        assertEq(token.balanceOf(alice, CLIENT_TOKEN_ID), 1);
        assertTrue(token.isValid(alice, CLIENT_TOKEN_ID));
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(pool)), PRICE);
        assertEq(_received(NETWORK), 3_500_000);
        assertEq(_received(BUILDER), 1_500_000);
        assertTrue(pool.hasPaid(alice));
    }

    function test_Pay_TwelveUnitsAddBonusDays() public {
        uint48 newExpiry = _pay(alice, MAX_UNITS);
        assertEq(newExpiry, uint48(T0) + 365 days);
        assertEq(uint256(MAX_UNITS) * UNIT + BONUS, 365 days);
    }

    function test_Pay_ElevenUnitsGetNoBonus() public {
        assertEq(_pay(alice, 11), uint48(T0) + 11 * UNIT);
    }

    function test_Pay_RenewalExtendsFromCurrentExpiry() public {
        _pay(alice, 2);
        vm.warp(T0 + 10 days);
        assertEq(_pay(alice, 3), uint48(T0) + 5 * UNIT);
    }

    function test_Pay_AfterExpiryStartsFromNow() public {
        _pay(alice, 1);
        vm.warp(T0 + 100 days);
        assertEq(_pay(alice, 1), uint48(T0 + 100 days) + UNIT);
    }

    function test_Pay_AtExactMaxPayment() public {
        _giveUsdc(alice, 3 * PRICE);
        vm.prank(alice);
        pool.payForAccess(3, 3 * PRICE, address(0));
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_Pay_ChargesCurrentPriceAfterChange() public {
        vm.prank(safe);
        pool.setPricing(6_000_000, UNIT, MAX_UNITS, BONUS);
        _giveUsdc(alice, 10_000_000);
        vm.prank(alice);
        pool.payForAccess(1, 10_000_000, address(0));
        assertEq(usdc.balanceOf(alice), 4_000_000);
    }

    // ------------------------------------------------------------------ payForAccess: expiry cap

    /// @dev A yearly client can renew a full year once 25 days or fewer remain: 25 + 365 = 390 = 13 units.
    function test_Pay_YearlyRenewalAllowedWith25DaysLeft() public {
        _pay(alice, MAX_UNITS);
        vm.warp(T0 + 340 days); // 25 days left
        assertEq(_pay(alice, MAX_UNITS), uint48(T0) + 730 days);
    }

    function test_Pay_RevertsPastCap() public {
        _pay(alice, MAX_UNITS);
        vm.warp(T0 + 339 days); // 26 days left
        uint256 newExpiry = T0 + 365 days + 365 days;
        uint256 latestAllowed = T0 + 339 days + 13 * uint256(UNIT);
        _giveUsdc(alice, MAX_UNITS * PRICE);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.ExpiryTooFar.selector, newExpiry, latestAllowed));
        pool.payForAccess(MAX_UNITS, MAX_UNITS * PRICE, address(0));
    }

    function test_Pay_CapCountsTimeMovedInByAdminTransfer() public {
        _pay(bob, MAX_UNITS);
        _pay(alice, 1);
        vm.prank(safe);
        token.adminTransfer(bob, alice, CLIENT_TOKEN_ID); // alice now has 395 days, above the cap
        _giveUsdc(alice, PRICE);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IPaymentPool.ExpiryTooFar.selector, T0 + 395 days + UNIT, T0 + 13 * uint256(UNIT))
        );
        pool.payForAccess(1, PRICE, address(0));
    }

    // ------------------------------------------------------------------ payForAccess: reverts

    function test_Pay_RevertsForInvalidUnits() public {
        _giveUsdc(alice, 100 * PRICE);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidUnits.selector, 0, MAX_UNITS));
        pool.payForAccess(0, 100 * PRICE, address(0));
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidUnits.selector, MAX_UNITS + 1, MAX_UNITS));
        pool.payForAccess(MAX_UNITS + 1, 100 * PRICE, address(0));
        vm.stopPrank();
    }

    function test_Pay_RevertsAboveMaxPayment() public {
        _giveUsdc(alice, 2 * PRICE);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.PriceAboveMax.selector, 2 * PRICE, 2 * PRICE - 1));
        pool.payForAccess(2, 2 * PRICE - 1, address(0));
    }

    /// @dev A price rise between quoting and paying is caught by maxPayment.
    function test_Pay_RevertsWhenPriceRoseAboveMaxPayment() public {
        _giveUsdc(alice, 10 * PRICE);
        vm.prank(safe);
        pool.setPricing(PRICE + 1, UNIT, MAX_UNITS, BONUS);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.PriceAboveMax.selector, PRICE + 1, PRICE));
        pool.payForAccess(1, PRICE, address(0));
    }

    function test_Pay_RevertsWhilePaused() public {
        _giveUsdc(alice, PRICE);
        vm.prank(safe);
        pool.pause();
        vm.prank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.payForAccess(1, PRICE, address(0));
    }

    function test_Pay_RevertsWithoutApproval() public {
        usdc.mint(alice, PRICE);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(pool), 0, PRICE)
        );
        pool.payForAccess(1, PRICE, address(0));
    }

    function test_Pay_RevertsWhenPoolIsNotMinter() public {
        vm.prank(safe);
        token.revokeRole(Roles.MINTER_ROLE, address(pool));
        _giveUsdc(alice, PRICE);
        vm.prank(alice);
        vm.expectRevert(_unauthorized(address(pool), Roles.MINTER_ROLE));
        pool.payForAccess(1, PRICE, address(0));
        assertEq(usdc.balanceOf(alice), PRICE);
        assertEq(_received(NETWORK) + _received(BUILDER), 0);
    }

    /// @dev A contract that can't receive ERC-1155 tokens can't pay; nothing is taken or recorded.
    function test_Pay_RevertsForPayerThatCannotReceiveToken() public {
        NonReceiver payer = new NonReceiver();
        _giveUsdc(address(payer), PRICE);
        vm.prank(address(payer));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(payer)));
        pool.payForAccess(1, PRICE, address(0));
        assertEq(usdc.balanceOf(address(payer)), PRICE);
        assertFalse(pool.hasPaid(address(payer)));
    }

    // ------------------------------------------------------------------ referrals

    function test_Referral_RecordedOnFirstPayment() public {
        _giveUsdc(alice, PRICE);
        vm.expectEmit(address(pool));
        emit IPaymentPool.ReferrerRecorded(alice, bob);
        vm.prank(alice);
        pool.payForAccess(1, PRICE, bob);
        assertEq(pool.referrerOf(alice), bob);
        assertTrue(pool.hasPaid(alice));
    }

    function test_Referral_LaterReferrerIgnored() public {
        _payWithReferrer(alice, 1, bob);
        vm.recordLogs();
        _payWithReferrer(alice, 1, carol);
        assertEq(pool.referrerOf(alice), bob);
        _assertNoReferrerEvent();
    }

    function test_Referral_ZeroReferrerClosesRecord() public {
        vm.recordLogs();
        _pay(alice, 1);
        _assertNoReferrerEvent();
        assertTrue(pool.hasPaid(alice));
        _payWithReferrer(alice, 1, bob);
        assertEq(pool.referrerOf(alice), address(0));
    }

    function test_Referral_SelfReferralRevertsOnFirstPayment() public {
        _giveUsdc(alice, PRICE);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.SelfReferral.selector);
        pool.payForAccess(1, PRICE, alice);
        assertFalse(pool.hasPaid(alice));
    }

    /// @dev After the first payment the referrer argument is not read, so naming yourself does nothing.
    function test_Referral_SelfOnLaterPaymentIgnored() public {
        _pay(alice, 1);
        _payWithReferrer(alice, 1, alice);
        assertEq(pool.referrerOf(alice), address(0));
    }

    /// @dev Reads the recorded logs once: exactly one purchase, and no ReferrerRecorded.
    function _assertNoReferrerEvent() private view {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 purchases;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pool)) continue;
            assertTrue(logs[i].topics[0] != IPaymentPool.ReferrerRecorded.selector);
            if (logs[i].topics[0] == IPaymentPool.AccessPurchased.selector) purchases++;
        }
        assertEq(purchases, 1);
    }

    // ------------------------------------------------------------------ split

    function test_Split_RoundingRemainderGoesToBuilder() public {
        vm.startPrank(safe);
        pool.setPricing(1, UNIT, MAX_UNITS, BONUS); // 1 base unit per unit
        pool.setNetworkSplitBps(SPLIT_BPS);
        vm.stopPrank();
        _pay(alice, 1); // 1 x 7000 / 10000 = 0 for Network
        assertEq(_received(NETWORK), 0);
        assertEq(_received(BUILDER), 1);
        _pay(bob, 3); // 3 x 0.7 = 2.1 -> 2 for Network
        assertEq(_received(NETWORK), 2);
        assertEq(_received(BUILDER), 2);
    }

    function test_Split_AllToOnePool() public {
        vm.prank(safe);
        pool.setNetworkSplitBps(10_000);
        _pay(alice, 1);
        assertEq(_received(NETWORK), PRICE);
        assertEq(_received(BUILDER), 0);

        vm.prank(safe);
        pool.setNetworkSplitBps(0);
        _pay(bob, 1);
        assertEq(_received(NETWORK), PRICE);
        assertEq(_received(BUILDER), PRICE);
    }

    function testFuzz_Split_AddsUpAndRoundsDown(uint256 price, uint8 units, uint16 bps) public {
        price = bound(price, 1, 1e15);
        units = uint8(bound(units, 1, MAX_UNITS));
        bps = uint16(bound(bps, 0, 10_000));
        vm.startPrank(safe);
        pool.setPricing(price, UNIT, MAX_UNITS, BONUS);
        pool.setNetworkSplitBps(bps);
        vm.stopPrank();

        _pay(alice, units);
        uint256 amount = price * units;
        uint256 network = _received(NETWORK);
        assertEq(network + _received(BUILDER), amount);
        assertEq(network, amount * bps / 10_000);
        assertLe(network * 10_000, amount * bps);
        assertEq(usdc.balanceOf(address(pool)), amount);
    }

    /// @dev Any purchase either lands at most 13 units ahead or reverts with ExpiryTooFar, from any expiry.
    function testFuzz_Cap_NeverExceeded(uint256 headStart, uint8 units) public {
        units = uint8(bound(units, 1, MAX_UNITS));
        headStart = bound(headStart, 0, 13 * uint256(UNIT));
        if (headStart > 0) {
            vm.prank(safe);
            token.grantRole(Roles.MINTER_ROLE, address(this));
            token.extendAccess(alice, CLIENT_TOKEN_ID, uint48(headStart));
        }
        uint256 duration = uint256(units) * UNIT + (units == MAX_UNITS ? BONUS : 0);
        uint256 latest = block.timestamp + 13 * uint256(UNIT);
        _giveUsdc(alice, pool.quote(units));
        vm.prank(alice);
        if (block.timestamp + headStart + duration > latest) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IPaymentPool.ExpiryTooFar.selector, block.timestamp + headStart + duration, latest
                )
            );
            pool.payForAccess(units, type(uint256).max, address(0));
        } else {
            uint48 newExpiry = pool.payForAccess(units, type(uint256).max, address(0));
            assertEq(newExpiry, block.timestamp + headStart + duration);
            assertLe(newExpiry, latest);
        }
    }

    // ------------------------------------------------------------------ fundPool

    function test_FundPool_AddsToLedgerAndEmits() public {
        _giveUsdc(carol, 1_000_000);
        vm.expectEmit(address(pool));
        emit IPaymentPool.PoolFunded(BUILDER, carol, 1_000_000);
        vm.prank(carol);
        pool.fundPool(BUILDER, 1_000_000);
        assertEq(_received(BUILDER), 1_000_000);
        assertEq(_received(NETWORK), 0);
        assertEq(usdc.balanceOf(address(pool)), 1_000_000);
        assertFalse(pool.hasPaid(carol));
    }

    function test_FundPool_WorksWhilePaused() public {
        vm.prank(safe);
        pool.pause();
        _fund(NETWORK, 2_000_000);
        assertEq(_received(NETWORK), 2_000_000);
    }

    function test_FundPool_RevertsForZeroAmount() public {
        vm.prank(carol);
        vm.expectRevert(IPaymentPool.ZeroAmount.selector);
        pool.fundPool(NETWORK, 0);
    }

    function test_FundPool_RevertsWithoutApproval() public {
        usdc.mint(carol, 1);
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(pool), 0, 1));
        pool.fundPool(NETWORK, 1);
    }

    /// @dev USDC sent without fundPool isn't counted in any pool, so no root can promise it.
    function test_DirectTransfer_NotCountedInAnyPool() public {
        usdc.mint(address(pool), 1_000_000);
        assertEq(_received(NETWORK) + _received(BUILDER), 0);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.TotalExceedsReceived.selector, NETWORK, 1, 0));
        pool.setMerkleRoot(NETWORK, keccak256("root"), 1, uint48(block.timestamp));
    }
}
