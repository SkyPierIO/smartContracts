// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Vm} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {ClientToken} from "../src/ClientToken.sol";
import {BETA_TESTER_BADGE_ID, CLIENT_TOKEN_ID, IClientToken} from "../src/interfaces/IClientToken.sol";
import {Roles} from "../src/lib/Roles.sol";
import {AcceptingReceiver, NonReceiver, ReentrantReceiver} from "./mocks/ERC1155ReceiverMocks.sol";
import {ClientTokenTestBase} from "./utils/ClientTokenTestBase.sol";

/// @notice Unit and fuzz tests for every ClientToken function: success paths, reverts and events.
contract ClientTokenTest is ClientTokenTestBase {
    // ---------------------------------------------------------------- initialize

    function test_Initialize_GrantsAdminAndUpgraderToSafeOnly() public view {
        assertTrue(token.hasRole(Roles.DEFAULT_ADMIN_ROLE, safe));
        assertTrue(token.hasRole(Roles.UPGRADER_ROLE, safe));
        assertFalse(token.hasRole(Roles.MINTER_ROLE, safe));
        assertFalse(token.hasRole(Roles.PAUSER_ROLE, safe));
        assertFalse(token.hasRole(Roles.DEFAULT_ADMIN_ROLE, address(this)));
        assertFalse(token.hasRole(Roles.UPGRADER_ROLE, address(this)));
        assertFalse(token.hasRole(Roles.MINTER_ROLE, address(this)));
    }

    function test_Initialize_SetsUri() public view {
        assertEq(token.uri(CLIENT_TOKEN_ID), URI_0);
    }

    /// @dev Reads the logs of the proxy deployment, since the proxy's address isn't known before it exists.
    function test_Initialize_EmitsUriAndRoleGrants() public {
        ClientToken impl = new ClientToken();
        vm.recordLogs();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ClientToken.initialize, (safe, URI_0)));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool adminGranted;
        bool upgraderGranted;
        bool uriEmitted;
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter != address(proxy)) continue;
            if (log.topics[0] == IAccessControl.RoleGranted.selector) {
                assertEq(log.topics[2], bytes32(uint256(uint160(safe))));
                assertEq(log.topics[3], bytes32(uint256(uint160(address(this)))));
                if (log.topics[1] == Roles.DEFAULT_ADMIN_ROLE) {
                    adminGranted = true;
                } else if (log.topics[1] == Roles.UPGRADER_ROLE) {
                    upgraderGranted = true;
                } else {
                    fail();
                }
            } else if (log.topics[0] == IERC1155.URI.selector) {
                assertEq(log.topics[1], bytes32(CLIENT_TOKEN_ID));
                assertEq(abi.decode(log.data, (string)), URI_0);
                uriEmitted = true;
            }
        }
        assertTrue(adminGranted);
        assertTrue(upgraderGranted);
        assertTrue(uriEmitted);
    }

    function test_Initialize_AcceptsEmptyUri() public {
        ClientToken t = _deploy(safe, "");
        assertEq(t.uri(CLIENT_TOKEN_ID), "");
    }

    function test_Initialize_RevertsOnZeroAdmin() public {
        ClientToken impl = new ClientToken();
        vm.expectRevert(IClientToken.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(ClientToken.initialize, (address(0), URI_0)));
    }

    function test_Initialize_CannotRunTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize(stranger, URI_0);
    }

    function test_Implementation_CannotBeInitialized() public {
        ClientToken impl = new ClientToken();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(stranger, URI_0);
    }

    // ---------------------------------------------------------------- extendAccess

    function test_ExtendAccess_MintsNewWallet() public {
        uint48 expected = uint48(T0) + UNIT;
        vm.expectEmit(true, true, false, true, address(token));
        emit IClientToken.AccessExtended(alice, CLIENT_TOKEN_ID, expected);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC1155.TransferSingle(minter, address(0), alice, CLIENT_TOKEN_ID, 1);

        uint48 newExpiry = _extend(alice, UNIT);

        assertEq(newExpiry, expected);
        assertEq(_expiry(alice), expected);
        assertEq(_balance(alice), 1);
        assertTrue(token.isValid(alice, CLIENT_TOKEN_ID));
    }

    function test_ExtendAccess_ActiveWalletExtendsFromExpiry() public {
        uint48 first = _extend(alice, UNIT);
        vm.warp(T0 + 10 days);

        vm.recordLogs();
        uint48 second = _extend(alice, UNIT);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(second, first + UNIT);
        assertEq(_balance(alice), 1);
        // Only AccessExtended: no second mint.
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], IClientToken.AccessExtended.selector);
    }

    function test_ExtendAccess_ExpiredWalletExtendsFromNow() public {
        _extend(alice, UNIT);
        uint256 later = T0 + UNIT + 5 days;
        vm.warp(later);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));

        vm.recordLogs();
        uint48 newExpiry = _extend(alice, UNIT);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(newExpiry, later + UNIT);
        assertEq(_balance(alice), 1);
        assertEq(logs.length, 1);
        assertTrue(token.isValid(alice, CLIENT_TOKEN_ID));
    }

    function test_ExtendAccess_ExactlyAtExpiryExtendsFromNow() public {
        uint48 first = _extend(alice, UNIT);
        vm.warp(first);
        assertEq(_extend(alice, UNIT), first + UNIT);
    }

    function test_ExtendAccess_RevertsForNonMinter() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.MINTER_ROLE));
        token.extendAccess(alice, CLIENT_TOKEN_ID, UNIT);
    }

    function test_ExtendAccess_RevertsForSafeWithoutMinterRole() public {
        vm.prank(safe);
        vm.expectRevert(_unauthorized(safe, Roles.MINTER_ROLE));
        token.extendAccess(alice, CLIENT_TOKEN_ID, UNIT);
    }

    function test_ExtendAccess_RevertsForBetaTesterBadge() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.UnsupportedId.selector, BETA_TESTER_BADGE_ID));
        token.extendAccess(alice, BETA_TESTER_BADGE_ID, UNIT);
    }

    function test_ExtendAccess_RevertsForIdZero() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.UnsupportedId.selector, 0));
        token.extendAccess(alice, 0, UNIT);
    }

    function test_ExtendAccess_RevertsForZeroAccount() public {
        vm.prank(minter);
        vm.expectRevert(IClientToken.ZeroAddress.selector);
        token.extendAccess(address(0), CLIENT_TOKEN_ID, UNIT);
    }

    function test_ExtendAccess_RevertsForZeroDuration() public {
        vm.prank(minter);
        vm.expectRevert(IClientToken.ZeroDuration.selector);
        token.extendAccess(alice, CLIENT_TOKEN_ID, 0);
    }

    function test_ExtendAccess_RevertsOnOverflow() public {
        vm.prank(minter);
        vm.expectRevert(IClientToken.ExpiryOverflow.selector);
        token.extendAccess(alice, CLIENT_TOKEN_ID, MAX);
    }

    function test_ExtendAccess_ReachesMaxExactly() public {
        uint48 d = MAX - uint48(T0);
        assertEq(_extend(alice, d), MAX);
        vm.prank(minter);
        vm.expectRevert(IClientToken.ExpiryOverflow.selector);
        token.extendAccess(alice, CLIENT_TOKEN_ID, 1);
    }

    function test_ExtendAccess_MintsToAcceptingContract() public {
        AcceptingReceiver wallet = new AcceptingReceiver();
        _extend(address(wallet), UNIT);
        assertEq(_balance(address(wallet)), 1);
        assertTrue(token.isValid(address(wallet), CLIENT_TOKEN_ID));
    }

    function test_ExtendAccess_RevertsForContractWithoutReceiverHook() public {
        NonReceiver wallet = new NonReceiver();
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(wallet)));
        token.extendAccess(address(wallet), CLIENT_TOKEN_ID, UNIT);
    }

    /// @dev The receiver sees the new expiry inside its hook (state written first), and its burn is refused.
    function test_ExtendAccess_ReceiverCannotReenterBurn() public {
        ReentrantReceiver wallet = new ReentrantReceiver(IClientToken(address(token)));
        uint48 newExpiry = _extend(address(wallet), UNIT);

        assertEq(wallet.expirySeenInHook(), newExpiry);
        assertFalse(wallet.burnSucceeded());
        bytes4 reentrancyError = ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector;
        assertEq(wallet.burnRevertData(), abi.encodeWithSelector(reentrancyError));
        assertEq(_balance(address(wallet)), 1);
        assertEq(_expiry(address(wallet)), newExpiry);
        assertTrue(token.isValid(address(wallet), CLIENT_TOKEN_ID));
    }

    // ---------------------------------------------------------------- burnClientToken

    function test_BurnClientToken_BurnsActiveToken() public {
        _extend(alice, UNIT);
        vm.expectEmit(true, true, false, true, address(token));
        emit IClientToken.AccessBurned(alice, CLIENT_TOKEN_ID);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC1155.TransferSingle(alice, alice, address(0), CLIENT_TOKEN_ID, 1);

        vm.prank(alice);
        token.burnClientToken();

        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));
    }

    function test_BurnClientToken_BurnsExpiredToken() public {
        _extend(alice, UNIT);
        vm.warp(T0 + UNIT + 1);
        vm.prank(alice);
        token.burnClientToken();
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
    }

    function test_BurnClientToken_RevertsWithoutToken() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, stranger, CLIENT_TOKEN_ID));
        token.burnClientToken();
    }

    function test_BurnClientToken_RevertsOnSecondBurn() public {
        _extend(alice, UNIT);
        vm.startPrank(alice);
        token.burnClientToken();
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, alice, CLIENT_TOKEN_ID));
        token.burnClientToken();
        vm.stopPrank();
    }

    function test_BurnClientToken_LaterPurchaseStartsFromNow() public {
        _extend(alice, 10 * UNIT);
        vm.prank(alice);
        token.burnClientToken();
        vm.warp(T0 + 1 days);
        assertEq(_extend(alice, UNIT), T0 + 1 days + UNIT);
        assertEq(_balance(alice), 1);
    }

    // ---------------------------------------------------------------- adminTransfer

    function test_AdminTransfer_ToEmptyWalletMovesToken() public {
        uint48 aliceExpiry = _extend(alice, UNIT);
        vm.warp(T0 + 10 days);
        uint48 expected = aliceExpiry; // now + (aliceExpiry - now)

        vm.expectEmit(true, true, true, true, address(token));
        emit IClientToken.AccessTransferred(alice, bob, CLIENT_TOKEN_ID, expected);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC1155.TransferSingle(safe, alice, bob, CLIENT_TOKEN_ID, 1);

        assertEq(_adminTransfer(alice, bob), expected);
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));
        assertEq(_balance(bob), 1);
        assertEq(_expiry(bob), expected);
        assertTrue(token.isValid(bob, CLIENT_TOKEN_ID));
    }

    function test_AdminTransfer_ToActiveWalletAddsRemainingAndBurnsOld() public {
        _extend(alice, 2 * UNIT);
        uint48 bobExpiry = _extend(bob, UNIT);
        vm.warp(T0 + 10 days);
        uint48 remaining = uint48(T0) + 2 * UNIT - uint48(T0 + 10 days);
        uint48 expected = bobExpiry + remaining;

        vm.expectEmit(true, true, true, true, address(token));
        emit IClientToken.AccessTransferred(alice, bob, CLIENT_TOKEN_ID, expected);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC1155.TransferSingle(safe, alice, address(0), CLIENT_TOKEN_ID, 1);

        assertEq(_adminTransfer(alice, bob), expected);
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
        assertEq(_balance(bob), 1);
        assertEq(_expiry(bob), expected);
    }

    function test_AdminTransfer_ToExpiredWalletStartsFromNow() public {
        _extend(bob, UNIT);
        vm.warp(T0 + UNIT + 3 days);
        uint48 aliceExpiry = _extend(alice, UNIT);

        assertEq(_adminTransfer(alice, bob), aliceExpiry);
        assertEq(_balance(alice), 0);
        assertEq(_balance(bob), 1);
        assertEq(_expiry(bob), aliceExpiry);
    }

    /// @dev Decision 2026-11-24: a recovery moves time already paid for, so the 13-unit cap doesn't apply.
    function test_AdminTransfer_IgnoresThirteenUnitCap() public {
        _extend(alice, 300 days);
        _extend(bob, 200 days);
        uint48 newExpiry = _adminTransfer(alice, bob);
        assertEq(newExpiry, uint48(T0) + 500 days);
        assertGt(newExpiry, uint48(T0) + 13 * UNIT);
    }

    function test_AdminTransfer_ToAcceptingContract() public {
        AcceptingReceiver wallet = new AcceptingReceiver();
        uint48 aliceExpiry = _extend(alice, UNIT);
        assertEq(_adminTransfer(alice, address(wallet)), aliceExpiry);
        assertEq(_balance(address(wallet)), 1);
    }

    function test_AdminTransfer_RevertsForContractWithoutReceiverHook() public {
        NonReceiver wallet = new NonReceiver();
        _extend(alice, UNIT);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(wallet)));
        token.adminTransfer(alice, address(wallet), CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsForStranger() public {
        _extend(alice, UNIT);
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.DEFAULT_ADMIN_ROLE));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsForMinter() public {
        _extend(alice, UNIT);
        vm.prank(minter);
        vm.expectRevert(_unauthorized(minter, Roles.DEFAULT_ADMIN_ROLE));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsForHolder() public {
        _extend(alice, UNIT);
        vm.prank(alice);
        vm.expectRevert(_unauthorized(alice, Roles.DEFAULT_ADMIN_ROLE));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsForUnsupportedId() public {
        _extend(alice, UNIT);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.UnsupportedId.selector, BETA_TESTER_BADGE_ID));
        token.adminTransfer(alice, bob, BETA_TESTER_BADGE_ID);
    }

    function test_AdminTransfer_RevertsForZeroReceiver() public {
        _extend(alice, UNIT);
        vm.prank(safe);
        vm.expectRevert(IClientToken.ZeroAddress.selector);
        token.adminTransfer(alice, address(0), CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsForSameAccount() public {
        _extend(alice, UNIT);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.SameAccount.selector, alice));
        token.adminTransfer(alice, alice, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsWhenSourceHasNoToken() public {
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, alice, CLIENT_TOKEN_ID));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsWhenSourceIsZero() public {
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, address(0), CLIENT_TOKEN_ID));
        token.adminTransfer(address(0), bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsWhenSourceExpired() public {
        _extend(alice, UNIT);
        vm.warp(T0 + UNIT + 1);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, alice, CLIENT_TOKEN_ID));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsExactlyAtSourceExpiry() public {
        uint48 aliceExpiry = _extend(alice, UNIT);
        vm.warp(aliceExpiry);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, alice, CLIENT_TOKEN_ID));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsWhenSourceBurned() public {
        _extend(alice, UNIT);
        vm.prank(alice);
        token.burnClientToken();
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IClientToken.NoAccess.selector, alice, CLIENT_TOKEN_ID));
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    function test_AdminTransfer_RevertsOnOverflow() public {
        _extend(alice, UNIT);
        _extend(bob, MAX - uint48(T0));
        vm.prank(safe);
        vm.expectRevert(IClientToken.ExpiryOverflow.selector);
        token.adminTransfer(alice, bob, CLIENT_TOKEN_ID);
    }

    // ---------------------------------------------------------------- setURI

    function test_SetURI_UpdatesAllIdsAndEmits() public {
        string memory newUri = "test://client-token/v2/{id}.json";
        vm.expectEmit(true, false, false, true, address(token));
        emit IERC1155.URI(newUri, CLIENT_TOKEN_ID);
        vm.prank(safe);
        token.setURI(newUri);
        assertEq(token.uri(CLIENT_TOKEN_ID), newUri);
        assertEq(token.uri(BETA_TESTER_BADGE_ID), newUri);
    }

    function test_SetURI_RevertsForNonAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.DEFAULT_ADMIN_ROLE));
        token.setURI("x");
    }

    // ---------------------------------------------------------------- isValid and expiryOf

    function test_IsValid_ExpiryBoundary() public {
        uint48 expiry = _extend(alice, UNIT);
        vm.warp(expiry - 1);
        assertTrue(token.isValid(alice, CLIENT_TOKEN_ID));
        vm.warp(expiry);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));
        vm.warp(expiry + 1);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));
    }

    function test_IsValid_FalseForUnknownWallet() public view {
        assertFalse(token.isValid(stranger, CLIENT_TOKEN_ID));
    }

    function test_IsValid_FalseForUnsupportedIds() public {
        _extend(alice, UNIT);
        assertFalse(token.isValid(alice, BETA_TESTER_BADGE_ID));
        assertFalse(token.isValid(alice, 0));
    }

    function test_ExpiryOf_ZeroForUnknownWallet() public view {
        assertEq(_expiry(stranger), 0);
    }

    function test_ExpiryOf_RevertsForUnsupportedId() public {
        vm.expectRevert(abi.encodeWithSelector(IClientToken.UnsupportedId.selector, BETA_TESTER_BADGE_ID));
        token.expiryOf(alice, BETA_TESTER_BADGE_ID);
    }

    // ---------------------------------------------------------------- id 2 reserved

    function test_BetaTesterBadge_StandardViewsDoNotRevert() public {
        _extend(alice, UNIT);
        assertEq(token.balanceOf(alice, BETA_TESTER_BADGE_ID), 0);
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = alice;
        uint256[] memory ids = new uint256[](2);
        ids[0] = CLIENT_TOKEN_ID;
        ids[1] = BETA_TESTER_BADGE_ID;
        uint256[] memory balances = token.balanceOfBatch(accounts, ids);
        assertEq(balances[0], 1);
        assertEq(balances[1], 0);
        assertEq(token.uri(BETA_TESTER_BADGE_ID), URI_0);
    }

    // ---------------------------------------------------------------- transfers and approvals disabled

    function test_SetApprovalForAll_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(IClientToken.TransfersDisabled.selector);
        token.setApprovalForAll(bob, true);
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_SafeTransferFrom_RevertsForHolder() public {
        _extend(alice, UNIT);
        vm.prank(alice);
        vm.expectRevert(IClientToken.TransfersDisabled.selector);
        token.safeTransferFrom(alice, bob, CLIENT_TOKEN_ID, 1, "");
        assertEq(_balance(alice), 1);
        assertEq(_balance(bob), 0);
    }

    function test_SafeTransferFrom_RevertsForSafe() public {
        _extend(alice, UNIT);
        vm.prank(safe);
        vm.expectRevert(IClientToken.TransfersDisabled.selector);
        token.safeTransferFrom(alice, bob, CLIENT_TOKEN_ID, 1, "");
    }

    function test_SafeBatchTransferFrom_Reverts() public {
        _extend(alice, UNIT);
        uint256[] memory ids = new uint256[](1);
        ids[0] = CLIENT_TOKEN_ID;
        uint256[] memory values = new uint256[](1);
        values[0] = 1;
        vm.prank(alice);
        vm.expectRevert(IClientToken.TransfersDisabled.selector);
        token.safeBatchTransferFrom(alice, bob, ids, values, "");
    }

    // ---------------------------------------------------------------- ERC-165

    function test_SupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155MetadataURI).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IClientToken).interfaceId));
        assertFalse(token.supportsInterface(0xffffffff));
    }

    /// @dev XOR of the six IClientToken selectors, computed by script. Changes if the interface changes.
    function test_ClientTokenInterfaceIdPinned() public pure {
        assertEq(type(IClientToken).interfaceId, bytes4(0xd9efab60));
    }

    // ---------------------------------------------------------------- fuzz

    function testFuzz_ExtendFromLaterOfNowAndExpiry(uint256 start, uint48 d1, uint256 gap, uint48 d2) public {
        start = bound(start, 1, 2 ** 40);
        d1 = uint48(bound(d1, 1, 2 ** 40));
        gap = bound(gap, 0, 2 ** 41);
        d2 = uint48(bound(d2, 1, 2 ** 40));

        vm.warp(start);
        uint48 first = _extend(alice, d1);
        assertEq(first, start + d1);

        uint256 now2 = start + gap;
        vm.warp(now2);
        uint48 second = _extend(alice, d2);
        uint256 base = now2 > first ? now2 : first;
        assertEq(second, base + d2);
        assertEq(_balance(alice), 1);
    }

    function testFuzz_ExtendOverflowBoundary(uint256 now_, uint48 duration) public {
        now_ = bound(now_, 1, MAX);
        duration = uint48(bound(duration, 1, MAX));
        vm.warp(now_);
        vm.prank(minter);
        if (now_ + duration > MAX) {
            vm.expectRevert(IClientToken.ExpiryOverflow.selector);
            token.extendAccess(alice, CLIENT_TOKEN_ID, duration);
        } else {
            assertEq(token.extendAccess(alice, CLIENT_TOKEN_ID, duration), now_ + duration);
        }
    }

    function testFuzz_IsValidBoundary(uint256 now_, uint48 duration, uint256 probe) public {
        now_ = bound(now_, 1, 2 ** 46);
        duration = uint48(bound(duration, 1, 2 ** 46));
        vm.warp(now_);
        uint48 expiry = _extend(alice, duration);
        probe = bound(probe, now_, uint256(expiry) + 2 ** 20);
        vm.warp(probe);
        assertEq(token.isValid(alice, CLIENT_TOKEN_ID), probe < expiry);
    }

    function testFuzz_AdminTransferMovesRemainingTime(
        uint48 dAlice,
        uint48 dBob,
        uint256 elapsed,
        bool bobHasToken,
        bool bobExpired
    ) public {
        dAlice = uint48(bound(dAlice, 2, 2 ** 40));
        dBob = uint48(bound(dBob, 1, 2 ** 40));
        if (bobHasToken) _extend(bob, dBob);
        _extend(alice, dAlice);

        uint256 bobExpiry = _expiry(bob);
        uint256 maxElapsed = dAlice - 1;
        if (bobHasToken && bobExpired && bobExpiry + 1 <= T0 + maxElapsed) {
            elapsed = bound(elapsed, bobExpiry + 1 - T0, maxElapsed);
        } else {
            elapsed = bound(elapsed, 0, maxElapsed);
        }
        uint256 now_ = T0 + elapsed;
        vm.warp(now_);

        uint256 remaining = uint256(_expiry(alice)) - now_;
        uint256 base = bobExpiry > now_ ? bobExpiry : now_;
        uint48 newExpiry = _adminTransfer(alice, bob);

        assertEq(newExpiry, base + remaining);
        assertEq(_expiry(bob), newExpiry);
        assertEq(_balance(bob), 1);
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
        // No paid time created or lost: bob's time left grew by exactly alice's time left.
        assertEq(uint256(newExpiry) - now_, (base - now_) + remaining);
    }

    function testFuzz_UnsupportedIdsRevert(uint256 id) public {
        vm.assume(id != CLIENT_TOKEN_ID);
        bytes memory err = abi.encodeWithSelector(IClientToken.UnsupportedId.selector, id);

        vm.prank(minter);
        vm.expectRevert(err);
        token.extendAccess(alice, id, UNIT);

        vm.prank(safe);
        vm.expectRevert(err);
        token.adminTransfer(alice, bob, id);

        vm.expectRevert(err);
        token.expiryOf(alice, id);

        assertFalse(token.isValid(alice, id));
    }

    function testFuzz_BurnAtAnyTime(uint48 duration, uint256 wait) public {
        duration = uint48(bound(duration, 1, 2 ** 40));
        wait = bound(wait, 0, 2 ** 41);
        _extend(alice, duration);
        vm.warp(T0 + wait);
        vm.prank(alice);
        token.burnClientToken();
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
        assertFalse(token.isValid(alice, CLIENT_TOKEN_ID));
    }
}
