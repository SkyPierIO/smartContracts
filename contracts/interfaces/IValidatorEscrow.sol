// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IValidatorEscrow {
    struct Stake {
        uint256 amount;
        uint256 depositedAt;
        bool active;
    }

    function depositFor(address beneficiary) external payable;
    function releaseStake(address beneficiary, address payable recipient) external;
    function slashStake(address beneficiary, address payable recipient, uint256 amount) external;
    function getStake(address beneficiary) external view returns (Stake memory);
}
