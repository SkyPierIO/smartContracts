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

    function warp(uint256 secondsAhead) external {
        secondsAhead = bound(secondsAhead, 1, 60 days);
        vm.warp(block.timestamp + secondsAhead);
    }
}

/// @notice Invariants that back isValid's one-read shortcut and adminTransfer's time accounting.
contract ClientTokenInvariantTest is ClientTokenTestBase {
    ClientTokenHandler internal handler;
    address[] internal actors;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(stranger);
        actors.push(address(new AcceptingReceiver()));
        actors.push(address(new ReentrantReceiver(IClientToken(address(token)))));

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

    /// @dev Nothing can hold or mint the reserved Beta Tester badge.
    function invariant_NoBetaTesterBadges() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            assertEq(token.balanceOf(actors[i], BETA_TESTER_BADGE_ID), 0);
        }
    }
}
