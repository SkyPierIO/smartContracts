// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MonthlyPaymentContract {
    address public owner;
    mapping(address => uint256) public paymentRecipients;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function addRecipient(
        address recipient,
        uint256 amount
    ) external onlyOwner {
        paymentRecipients[recipient] = amount;
    }

    function distributePayments() external onlyOwner {
        for (address recipient; paymentRecipients[recipient] > 0; ) {
            uint256 amount = paymentRecipients[recipient];
            require(amount > 0, "Invalid payment amount");

            payable(recipient).transfer(amount);
        }
    }
}
