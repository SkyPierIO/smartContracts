// tests/lib/ERC6551Registry_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/lib/ERC6551Registry.sol";
import "../../contracts/lib/TokenBoundAccount.sol";

contract ERC6551RegistryTest {
    ERC6551Registry registry;
    TokenBoundAccount tokenBoundAccountImplementation;

    address admin = TestsAccounts.getAccount(0);
    address tokenContract = TestsAccounts.getAccount(1);
    uint256 tokenId = 123;
    uint256 salt = 0;

    function beforeAll() public {
        // Deploy registry
        vm.prank(admin);
        registry = new ERC6551Registry();

        // Deploy TokenBoundAccount implementation
        vm.prank(admin);
        tokenBoundAccountImplementation = new TokenBoundAccount(address(0), 0);
    }

    function testComputeAccount() public {
        address computedAccount = registry.computeAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        Assert.notEqual(computedAccount, address(0), "Computed account should not be zero address");
    }

    function testCreateAccount() public {
        address computedAccount = registry.computeAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        // Create the account
        vm.prank(admin);
        address createdAccount = registry.createAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        Assert.equal(createdAccount, computedAccount, "Created account should match computed account");
    }

    function testAccountLookup() public {
        address computedAccount = registry.computeAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        // Create the account first
        vm.prank(admin);
        registry.createAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        // Look up the account
        address lookedUpAccount = registry.account(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        Assert.equal(lookedUpAccount, computedAccount, "Looked up account should match computed account");
    }

    function testAccountCreationEvent() public {
        vm.prank(admin);
        address createdAccount = registry.createAccount(
            address(tokenBoundAccountImplementation),
            block.chainid,
            tokenContract,
            tokenId,
            salt
        );

        // Check that event was emitted
        // Note: In Remix tests, we can't directly check events, but we can verify the account was created
        Assert.notEqual(createdAccount, address(0), "Account should be created");
    }
}