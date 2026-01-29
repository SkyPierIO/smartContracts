// contracts/interfaces/IPaymentPool.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPaymentPool {
    function deposit() external payable;
    function distributePayments() external;
    function getNetworkPoolBalance() external view returns (uint256);
    function getBuilderPoolBalance() external view returns (uint256);
}