// tests/lib/TokenBoundAccount_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/lib/TokenBoundAccount.sol";

contract TokenBoundAccountTest {
    TokenBoundAccount account;
    address tokenContract = TestsAccounts.getAccount(1);
    uint256 tokenId = 123;

    address admin = TestsAccounts.getAccount(0);
    address otherAccount = TestsAccounts.getAccount(2);

    function beforeAll() public {
        // Deploy TokenBoundAccount
        vm.prank(admin);
        account = new TokenBoundAccount(tokenContract, tokenId);
    }

    function testTokenInfo() public {
        (address contract, uint256 id) = account.token();
        Assert.equal(contract, tokenContract, "Token contract should match");
        Assert.equal(id, tokenId, "Token ID should match");
    }

    function testIsValidSigner() public {
        // Owner should be valid signer
        Assert.ok(account.isValidSigner(admin, ""), "Owner should be valid signer");

        // Other account should not be valid signer
        Assert.ok(!account.isValidSigner(otherAccount, ""), "Other account should not be valid signer");
    }

    function testReceiveETH() public {
        // Send ETH to the account
        vm.deal(address(account), 0.1 ether);

        // Check balance
        Assert.equal(address(account).balance, 0.1 ether, "Account should have 0.1 ETH");
    }

    function testSupportsInterface() public {
        // Check ERC165 support
        Assert.ok(account.supportsInterface(0x01FFC9A7), "Should support ERC165");

        // Check ITokenBoundAccount support
        Assert.ok(account.supportsInterface(type(ITokenBoundAccount).interfaceId), "Should support ITokenBoundAccount");
    }
}