// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {PaymentPool} from "../src/PaymentPool.sol";
import {IClientToken} from "../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../src/interfaces/IPaymentPool.sol";
import {Roles} from "../src/lib/Roles.sol";
import {PaymentPoolTestBase} from "./utils/PaymentPoolTestBase.sol";

/// @notice Setup, settings, pause, quote and ERC-165.
contract PaymentPoolSetupTest is PaymentPoolTestBase {
    /// @dev XOR of the 18 IPaymentPool function selectors, computed by script from `solc --hashes`.
    bytes4 internal constant PAYMENT_POOL_INTERFACE_ID = 0xa4a51290;

    // ------------------------------------------------------------------ initialize

    function test_Initialize_SetsAddressesSettingsAndRoles() public view {
        assertEq(pool.usdc(), address(usdc));
        assertEq(pool.clientToken(), address(token));
        (uint256 price, uint48 unitLength, uint16 maxUnits, uint48 bonus) = pool.pricing();
        assertEq(price, PRICE);
        assertEq(unitLength, UNIT);
        assertEq(maxUnits, MAX_UNITS);
        assertEq(bonus, BONUS);
        assertEq(pool.networkSplitBps(), SPLIT_BPS);
        assertFalse(pool.paused());

        assertTrue(pool.hasRole(Roles.DEFAULT_ADMIN_ROLE, safe));
        assertTrue(pool.hasRole(Roles.UPGRADER_ROLE, safe));
        assertTrue(pool.hasRole(Roles.PAUSER_ROLE, safe));
        assertFalse(pool.hasRole(Roles.DEFAULT_ADMIN_ROLE, address(this)));
        assertFalse(pool.hasRole(Roles.UPGRADER_ROLE, address(this)));
        assertFalse(pool.hasRole(Roles.PAUSER_ROLE, address(this)));

        for (uint8 p; p < 2; ++p) {
            (bytes32 root, uint256 received, uint256 claimed, uint256 rootTotal, uint48 lastEnd) =
                pool.poolLedger(IPaymentPool.Pool(p));
            assertEq(root, bytes32(0));
            assertEq(received + claimed + rootTotal + lastEnd, 0);
        }
    }

    function test_Initialize_EmitsStartingSettings() public {
        vm.recordLogs();
        PaymentPool fresh = _deployPool(safe, address(usdc), address(token));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool sawPricing;
        bool sawSplit;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(fresh)) continue;
            if (logs[i].topics[0] == IPaymentPool.PricingUpdated.selector) {
                assertEq(logs[i].data, abi.encode(PRICE, UNIT, MAX_UNITS, BONUS));
                sawPricing = true;
            } else if (logs[i].topics[0] == IPaymentPool.NetworkSplitUpdated.selector) {
                assertEq(logs[i].data, abi.encode(uint16(0), SPLIT_BPS));
                sawSplit = true;
            }
        }
        assertTrue(sawPricing);
        assertTrue(sawSplit);
    }

    function test_Initialize_RevertsForZeroAdmin() public {
        _expectDeployRevert(_initData(address(0), address(usdc), address(token)), IPaymentPool.ZeroAddress.selector);
    }

    function test_Initialize_RevertsForZeroUsdc() public {
        _expectDeployRevert(_initData(safe, address(0), address(token)), IPaymentPool.ZeroAddress.selector);
    }

    function test_Initialize_RevertsForZeroClientToken() public {
        _expectDeployRevert(_initData(safe, address(usdc), address(0)), IPaymentPool.ZeroAddress.selector);
    }

    function test_Initialize_RevertsWhenClientTokenIsNotAClientToken() public {
        address impl = _newPoolImpl();
        // A contract without ERC-165 (the USDC mock), and a wallet with no code.
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidClientToken.selector, address(usdc)));
        new ERC1967Proxy(impl, _initData(safe, address(usdc), address(usdc)));
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidClientToken.selector, stranger));
        new ERC1967Proxy(impl, _initData(safe, address(usdc), stranger));
        // A contract with ERC-165 that isn't a ClientToken: another PaymentPool.
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidClientToken.selector, address(pool)));
        new ERC1967Proxy(impl, _initData(safe, address(usdc), address(pool)));
    }

    function test_Initialize_RevertsForBonusLongerThanUnit() public {
        bytes memory data = abi.encodeCall(
            PaymentPool.initialize, (safe, address(usdc), address(token), PRICE, UNIT, MAX_UNITS, UNIT + 1, SPLIT_BPS)
        );
        _expectDeployRevert(data, IPaymentPool.InvalidPricing.selector);
    }

    function test_Initialize_RevertsForSplitAbove100Percent() public {
        bytes memory data = abi.encodeCall(
            PaymentPool.initialize, (safe, address(usdc), address(token), PRICE, UNIT, MAX_UNITS, BONUS, 10_001)
        );
        address impl = _newPoolImpl(); // deploy before expectRevert, which applies to the next call only
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidSplit.selector, uint256(10_001)));
        new ERC1967Proxy(impl, data);
    }

    function test_Initialize_CannotRunTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        pool.initialize(stranger, address(usdc), address(token), PRICE, UNIT, MAX_UNITS, BONUS, SPLIT_BPS);
    }

    function test_Implementation_CannotBeInitialized() public {
        PaymentPool impl = PaymentPool(_newPoolImpl());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(safe, address(usdc), address(token), PRICE, UNIT, MAX_UNITS, BONUS, SPLIT_BPS);
    }

    function _expectDeployRevert(bytes memory data, bytes4 selector) private {
        address impl = _newPoolImpl();
        vm.expectRevert(selector);
        new ERC1967Proxy(impl, data);
    }

    // ------------------------------------------------------------------ ERC-165

    function test_InterfaceId_IsPinned() public pure {
        assertEq(type(IPaymentPool).interfaceId, PAYMENT_POOL_INTERFACE_ID);
    }

    function test_SupportsInterface() public view {
        assertTrue(pool.supportsInterface(type(IPaymentPool).interfaceId));
        assertTrue(pool.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC165).interfaceId));
        assertFalse(pool.supportsInterface(type(IClientToken).interfaceId));
        assertFalse(pool.supportsInterface(0xffffffff));
    }

    // ------------------------------------------------------------------ setPricing

    function test_SetPricing_StoresAndEmits() public {
        vm.expectEmit(address(pool));
        emit IPaymentPool.PricingUpdated(7_000_000, 7 days, 6, 7 days);
        vm.prank(safe);
        pool.setPricing(7_000_000, 7 days, 6, 7 days); // bonus equal to one unit is allowed

        (uint256 price, uint48 unitLength, uint16 maxUnits, uint48 bonus) = pool.pricing();
        assertEq(price, 7_000_000);
        assertEq(unitLength, 7 days);
        assertEq(maxUnits, 6);
        assertEq(bonus, 7 days);
        assertEq(pool.quote(6), 42_000_000);
    }

    function test_SetPricing_AllowsZeroBonus() public {
        vm.prank(safe);
        pool.setPricing(PRICE, UNIT, MAX_UNITS, 0);
        (,,, uint48 bonus) = pool.pricing();
        assertEq(bonus, 0);
    }

    function test_SetPricing_RevertsForInvalidValues() public {
        vm.startPrank(safe);
        vm.expectRevert(IPaymentPool.InvalidPricing.selector);
        pool.setPricing(0, UNIT, MAX_UNITS, BONUS);
        vm.expectRevert(IPaymentPool.InvalidPricing.selector);
        pool.setPricing(PRICE, 0, MAX_UNITS, 0);
        vm.expectRevert(IPaymentPool.InvalidPricing.selector);
        pool.setPricing(PRICE, UNIT, 0, BONUS);
        vm.expectRevert(IPaymentPool.InvalidPricing.selector);
        pool.setPricing(PRICE, UNIT, MAX_UNITS, UNIT + 1);
        vm.stopPrank();
    }

    function test_SetPricing_OnlyAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.DEFAULT_ADMIN_ROLE));
        pool.setPricing(PRICE, UNIT, MAX_UNITS, BONUS);
    }

    function test_SetPricing_WorksWhilePaused() public {
        vm.startPrank(safe);
        pool.pause();
        pool.setPricing(PRICE, UNIT, MAX_UNITS, 0);
        vm.stopPrank();
        (,,, uint48 bonus) = pool.pricing();
        assertEq(bonus, 0);
    }

    // ------------------------------------------------------------------ setNetworkSplitBps

    function test_SetNetworkSplitBps_StoresAndEmits() public {
        vm.expectEmit(address(pool));
        emit IPaymentPool.NetworkSplitUpdated(SPLIT_BPS, 6000);
        vm.prank(safe);
        pool.setNetworkSplitBps(6000);
        assertEq(pool.networkSplitBps(), 6000);
    }

    function test_SetNetworkSplitBps_AcceptsBounds() public {
        vm.startPrank(safe);
        pool.setNetworkSplitBps(0);
        assertEq(pool.networkSplitBps(), 0);
        pool.setNetworkSplitBps(10_000);
        assertEq(pool.networkSplitBps(), 10_000);
        vm.stopPrank();
    }

    function test_SetNetworkSplitBps_RevertsAbove100Percent() public {
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidSplit.selector, uint256(10_001)));
        pool.setNetworkSplitBps(10_001);
    }

    function test_SetNetworkSplitBps_OnlyAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.DEFAULT_ADMIN_ROLE));
        pool.setNetworkSplitBps(5000);
    }

    // ------------------------------------------------------------------ pause

    function test_Pause_ByPauserAndUnpauseByAdmin() public {
        vm.expectEmit(address(pool));
        emit PausableUpgradeable.Paused(safe);
        vm.prank(safe);
        pool.pause();
        assertTrue(pool.paused());

        vm.expectEmit(address(pool));
        emit PausableUpgradeable.Unpaused(safe);
        vm.prank(safe);
        pool.unpause();
        assertFalse(pool.paused());
    }

    /// @dev A pause-only key (for example a monitoring bot) can pause but never unpause.
    function test_Pause_PauseOnlyKeyCannotUnpause() public {
        address monitor = makeAddr("monitor");
        vm.prank(safe);
        pool.grantRole(Roles.PAUSER_ROLE, monitor);

        vm.prank(monitor);
        pool.pause();
        assertTrue(pool.paused());

        vm.prank(monitor);
        vm.expectRevert(_unauthorized(monitor, Roles.DEFAULT_ADMIN_ROLE));
        pool.unpause();
    }

    function test_Pause_OnlyPauser() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.PAUSER_ROLE));
        pool.pause();
    }

    function test_Pause_RevertsWhenAlreadyPausedAndUnpauseWhenNot() public {
        vm.startPrank(safe);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        pool.unpause();
        pool.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.pause();
        vm.stopPrank();
    }

    // ------------------------------------------------------------------ quote and views

    function test_Quote() public view {
        assertEq(pool.quote(1), PRICE);
        assertEq(pool.quote(3), 3 * PRICE);
        assertEq(pool.quote(MAX_UNITS), MAX_UNITS * PRICE);
    }

    function test_Quote_RevertsOutsideRange() public {
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidUnits.selector, 0, MAX_UNITS));
        pool.quote(0);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.InvalidUnits.selector, MAX_UNITS + 1, MAX_UNITS));
        pool.quote(MAX_UNITS + 1);
    }

    function test_Views_DefaultForUnknownWallet() public view {
        assertEq(pool.referrerOf(stranger), address(0));
        assertFalse(pool.hasPaid(stranger));
        assertEq(pool.claimedOf(NETWORK, stranger), 0);
        assertEq(pool.claimedOf(BUILDER, stranger), 0);
    }
}
