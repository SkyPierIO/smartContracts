// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ClientToken} from "../../src/ClientToken.sol";
import {BETA_TESTER_BADGE_ID, CLIENT_TOKEN_ID, IClientToken} from "../../src/interfaces/IClientToken.sol";
import {AcceptingReceiver, ReentrantReceiver} from "../mocks/ERC1155ReceiverMocks.sol";
import {ClientTokenTestBase} from "../utils/ClientTokenTestBase.sol";

/// @notice Drives ClientToken with random sequences of extend, burn, adminTransfer and time passing.
/// @dev Inputs are bounded so most calls succeed. The handler checks, at each adminTransfer, that the receiving
/// wallet's time left grows by exactly the sender's time left (no paid time created or lost).
contract ClientTokenHandler is Test {
    ClientToken public immutable token;
    address public immutable safe;
    address public immutable minter;
    address[] public actors;

    uint256 public transferMismatches;
    uint256 public unsupportedIdSuccesses;
    uint256 public unsupportedIdWrongErrors;
    uint256 public unsupportedIdAttempts;
    uint256 public calls;

    constructor(ClientToken token_, address safe_, address minter_, address[] memory actors_) {
        token = token_;
        safe = safe_;
        minter = minter_;
        actors = actors_;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function extend(uint256 actorSeed, uint48 duration) external {
        duration = uint48(bound(duration, 1, 400 days));
        vm.prank(minter);
        token.extendAccess(_actor(actorSeed), CLIENT_TOKEN_ID, duration);
        calls++;
    }

    function burn(uint256 actorSeed) external {
        address account = _actor(actorSeed);
        if (token.balanceOf(account, CLIENT_TOKEN_ID) == 0) return;
        vm.prank(account);
        token.burnClientToken();
        calls++;
    }

    function adminTransfer(uint256 fromSeed, uint256 toSeed) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint48 fromExpiry = token.expiryOf(from, CLIENT_TOKEN_ID);
        if (from == to || fromExpiry <= block.timestamp) return;

        uint256 toExpiry = token.expiryOf(to, CLIENT_TOKEN_ID);
        uint256 toLeftBefore = toExpiry > block.timestamp ? toExpiry - block.timestamp : 0;
        uint256 fromLeft = fromExpiry - block.timestamp;

        vm.prank(safe);
        uint48 newExpiry = token.adminTransfer(from, to, CLIENT_TOKEN_ID);
        if (uint256(newExpiry) - block.timestamp != toLeftBefore + fromLeft) transferMismatches++;
        calls++;
    }

    /// @dev Tries to mint or move an unsupported id: 0, 2 (the Beta Tester badge) or 3. Every attempt must revert.
    function tryUnsupportedId(uint256 idSeed, uint256 fromSeed, uint256 toSeed, bool viaTransfer) external {
        uint256 id = bound(idSeed, 0, 3);
        if (id == CLIENT_TOKEN_ID) id = BETA_TESTER_BADGE_ID;
        unsupportedIdAttempts++;
        if (viaTransfer) {
            vm.prank(safe);
            try token.adminTransfer(_actor(fromSeed), _actor(toSeed), id) {
                unsupportedIdSuccesses++;
            } catch (bytes memory reason) {
                _checkUnsupportedId(reason, id);
            }
        } else {
            vm.prank(minter);
            try token.extendAccess(_actor(toSeed), id, 30 days) {
                unsupportedIdSuccesses++;
            } catch (bytes memory reason) {
                _checkUnsupportedId(reason, id);
            }
        }
    }

    /// @dev Counts any revert that isn't UnsupportedId(id), such as NoAccess or SameAccount from a later check.
    function _checkUnsupportedId(bytes memory reason, uint256 id) internal {
        if (keccak256(reason) != keccak256(abi.encodeWithSelector(IClientToken.UnsupportedId.selector, id))) {
            unsupportedIdWrongErrors++;
        }
    }

    function warp(uint256 secondsAhead) external {
        secondsAhead = bound(secondsAhead, 1, 60 days);
        vm.warp(block.timestamp + secondsAhead);
    }
}

/// @notice Invariants that back isValid's one-read shortcut and adminTransfer's time accounting.
contract ClientTokenInvariantTest is ClientTokenTestBase {
    ClientTokenHandler internal handler;
    ReentrantReceiver internal reentrantWallet;
    address[] internal actors;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(stranger);
        actors.push(address(new AcceptingReceiver()));
        reentrantWallet = new ReentrantReceiver(IClientToken(address(token)));
        actors.push(address(reentrantWallet));

        handler = new ClientTokenHandler(token, safe, minter, actors);
        targetContract(address(handler));
    }

    /// @dev A wallet never holds more than one Client token.
    function invariant_AtMostOneTokenPerWallet() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            assertLe(token.balanceOf(actors[i], CLIENT_TOKEN_ID), 1);
        }
    }

    /// @dev No token means expiry 0, and a token means a non-zero expiry. isValid relies on this.
    function invariant_NoTokenMeansZeroExpiry() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            bool hasToken = token.balanceOf(actors[i], CLIENT_TOKEN_ID) == 1;
            bool hasExpiry = token.expiryOf(actors[i], CLIENT_TOKEN_ID) != 0;
            assertEq(hasToken, hasExpiry);
        }
    }

    /// @dev isValid's one storage read gives the same answer as the interface's definition.
    function invariant_IsValidMatchesDefinition() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            bool holds = token.balanceOf(actors[i], CLIENT_TOKEN_ID) == 1;
            bool beforeExpiry = block.timestamp < token.expiryOf(actors[i], CLIENT_TOKEN_ID);
            assertEq(token.isValid(actors[i], CLIENT_TOKEN_ID), holds && beforeExpiry);
        }
    }

    /// @dev adminTransfer never creates or loses paid time.
    function invariant_AdminTransferConservesTime() public view {
        assertEq(handler.transferMismatches(), 0);
    }

    /// @dev Nothing can hold or mint the reserved Beta Tester badge, or any id other than 1. The handler's
    /// tryUnsupportedId action attempts it; every attempt must revert.
    function invariant_NoBetaTesterBadges() public view {
        assertEq(handler.unsupportedIdSuccesses(), 0);
        assertEq(handler.unsupportedIdWrongErrors(), 0);
        for (uint256 i = 0; i < actors.length; i++) {
            assertEq(token.balanceOf(actors[i], BETA_TESTER_BADGE_ID), 0);
            assertEq(token.balanceOf(actors[i], 0), 0);
            assertEq(token.balanceOf(actors[i], 3), 0);
        }
    }

    /// @dev A receiver's attempt to burn from inside the mint or transfer hook is always refused.
    function invariant_ReceiverHookCannotReenter() public view {
        assertFalse(reentrantWallet.burnSucceeded());
    }
}
