// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NodeConfigContract {
    address public owner;
    mapping(address => uint256) public paymentRecipients;

    constructor() {
        owner = msg.sender;
    }
}
