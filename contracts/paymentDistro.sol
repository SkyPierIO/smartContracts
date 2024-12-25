// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// AutomationCompatible.sol imports the functions from both ./AutomationBase.sol and
// ./interfaces/AutomationCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

// Get all active Node NFTs from AllActiveNodeNFT
contract MonthlyPaymentContract {
    address public owner; // Wallet address from Unlock

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

// Filter to all active Node NFTs
contract AllActiveNodeNFT is ERC721 {

}
