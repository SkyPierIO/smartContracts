// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IPaymentPool} from "../../src/interfaces/IPaymentPool.sol";

/// @notice Test-only payer contract. When ClientToken mints to it during payForAccess, its receiver hook makes one
/// call back into PaymentPool and records what happened, plus what the pool's ledger showed at that moment.
contract ReentrantPayer is IERC1155Receiver {
    IPaymentPool public immutable pool;

    bytes public reentryCall;
    bool public attempted;
    bool public reentrySucceeded;
    bytes public reentryResult;
    uint256 public networkReceivedDuringHook;
    bool public hasPaidDuringHook;

    constructor(IPaymentPool pool_, IERC20 usdc) {
        pool = pool_;
        usdc.approve(address(pool_), type(uint256).max);
    }

    function setReentry(bytes calldata data) external {
        reentryCall = data;
    }

    function pay(uint256 units, uint256 maxPayment) external returns (uint48) {
        return pool.payForAccess(units, maxPayment, address(0));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (!attempted) {
            attempted = true;
            (, networkReceivedDuringHook,,,) = pool.poolLedger(IPaymentPool.Pool.Network);
            hasPaidDuringHook = pool.hasPaid(address(this));
            if (reentryCall.length != 0) (reentrySucceeded, reentryResult) = address(pool).call(reentryCall);
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
