// contracts/interfaces/IPaymentPool.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPaymentPool {
    function deposit() external payable;
    function distributePayments() external;
    function registerOperator(address payable operator) external;
    function registerValidator(address payable validator) external;
    function deactivateParticipant(address participant, string calldata role) external;
    function reactivateParticipant(address participant, string calldata role) external;
    function recordOperatorMetrics(address operator, uint256 dataVolume, uint256 duration) external;
    function getNetworkPoolBalance() external view returns (uint256);
    function getBuilderPoolBalance() external view returns (uint256);
}