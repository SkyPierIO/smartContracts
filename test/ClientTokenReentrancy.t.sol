// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IClientToken} from "../src/interfaces/IClientToken.sol";
import {ReentrantReceiver} from "./mocks/ERC1155ReceiverMocks.sol";
import {ClientTokenTestBase} from "./utils/ClientTokenTestBase.sol";

/// @notice Receiver-hook reentrancy through adminTransfer. Kept apart from ClientTokenTest, which is close to the
/// 49,152-byte initcode limit for contract creation.
contract ClientTokenReentrancyTest is ClientTokenTestBase {
    /// @dev The receiver sees its new expiry inside the hook (state written first), and its burn is refused.
    function test_AdminTransfer_ReceiverCannotReenterBurn() public {
        ReentrantReceiver wallet = new ReentrantReceiver(IClientToken(address(token)));
        uint48 aliceExpiry = _extend(alice, UNIT);
        vm.warp(T0 + 10 days);

        uint48 newExpiry = _adminTransfer(alice, address(wallet));

        assertEq(newExpiry, aliceExpiry);
        assertEq(wallet.expirySeenInHook(), newExpiry);
        assertFalse(wallet.burnSucceeded());
        bytes4 reentrancyError = ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector;
        assertEq(wallet.burnRevertData(), abi.encodeWithSelector(reentrancyError));
        assertEq(_balance(address(wallet)), 1);
        assertEq(_expiry(address(wallet)), newExpiry);
        assertEq(_balance(alice), 0);
        assertEq(_expiry(alice), 0);
    }
}
