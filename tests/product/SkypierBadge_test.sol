// tests/product/SkypierBadges_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/SkypierBadges.sol";
import "../../contracts/lib/ERC6551Registry.sol";
import "../../contracts/lib/TokenBoundAccount.sol";

contract SkypierBadgesTest {
    SkypierBadges badges;
    ERC6551Registry registry;
    TokenBoundAccount tokenBoundAccountImplementation;

    address admin = TestsAccounts.getAccount(0);
    address client = TestsAccounts.getAccount(1);
    address operator = TestsAccounts.getAccount(2);
    address validator = TestsAccounts.getAccount(3);

    function beforeAll() public {
        // Deploy registry
        vm.prank(admin);
        registry = new ERC6551Registry();

        // Deploy TokenBoundAccount implementation
        vm.prank(admin);
        tokenBoundAccountImplementation = new TokenBoundAccount(address(0), 0);

        // Deploy SkypierBadges with registry
        vm.prank(admin);
        badges = new SkypierBadges(address(registry), address(tokenBoundAccountImplementation));
    }

    function testMintClientBadge() public {
        vm.prank(admin);
        badges.mintClientBadge(client);

        Assert.equal(badges.balanceOf(client, badges.CLIENT_BADGE()), 1, "Client should have 1 badge");

        // Get the token ID
        uint256 tokenId = badges.tokenOfOwnerByIndex(client, 0);

        // Check TokenBoundAccount was created
        address account = badges.getTokenBoundAccount(tokenId);
        Assert.notEqual(account, address(0), "TokenBoundAccount should be created");

        // Verify the account's token info
        (address tokenContract, uint256 badgeTokenId) = ITokenBoundAccount(account).token();
        Assert.equal(tokenContract, address(badges), "Token contract should match");
        Assert.equal(badgeTokenId, tokenId, "Token ID should match");
    }

    function testMintOperatorBadge() public {
        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";

        vm.prank(admin);
        badges.mintOperatorBadge(operator, peerId);

        Assert.equal(badges.balanceOf(operator, badges.OPERATOR_BADGE()), 1, "Operator should have 1 badge");

        // Get the token ID
        uint256 tokenId = badges.tokenOfOwnerByIndex(operator, 0);

        // Check PeerID was stored
        string memory storedPeerId = badges.getOperatorPeerId(tokenId);
        Assert.equal(storedPeerId, peerId, "PeerID should match");

        // Check TokenBoundAccount was created
        address account = badges.getTokenBoundAccount(tokenId);
        Assert.notEqual(account, address(0), "TokenBoundAccount should be created");
    }

    function testMintValidatorBadge() public {
        vm.prank(admin);
        badges.mintValidatorBadge(validator);

        Assert.equal(badges.balanceOf(validator, badges.VALIDATOR_BADGE()), 1, "Validator should have 1 badge");

        // Get the token ID
        uint256 tokenId = badges.tokenOfOwnerByIndex(validator, 0);

        // Check TokenBoundAccount was created
        address account = badges.getTokenBoundAccount(tokenId);
        Assert.notEqual(account, address(0), "TokenBoundAccount should be created");
    }

    function testTokenBoundAccountFunctionality() public {
        // Mint a badge
        vm.prank(admin);
        badges.mintClientBadge(client);

        // Get the token ID and account
        uint256 tokenId = badges.tokenOfOwnerByIndex(client, 0);
        address account = badges.getTokenBoundAccount(tokenId);

        // Send ETH to the account
        vm.deal(address(account), 0.1 ether);

        // Check balance
        Assert.equal(account.balance, 0.1 ether, "Account should have 0.1 ETH");

        // Verify token info
        (address tokenContract, uint256 badgeTokenId) = ITokenBoundAccount(account).token();
        Assert.equal(tokenContract, address(badges), "Token contract should match");
        Assert.equal(badgeTokenId, tokenId, "Token ID should match");
    }

    function testUnauthorizedMint() public {
        // Try to mint without admin role
        vm.expectRevert("Not authorized");
        vm.prank(client);
        badges.mintClientBadge(client);
    }

    function testBadgeTypes() public {
        // Mint different badge types
        vm.prank(admin);
        badges.mintClientBadge(client);
        vm.prank(admin);
        badges.mintOperatorBadge(operator, "peerId");
        vm.prank(admin);
        badges.mintValidatorBadge(validator);

        // Get token IDs
        uint256 clientTokenId = badges.tokenOfOwnerByIndex(client, 0);
        uint256 operatorTokenId = badges.tokenOfOwnerByIndex(operator, 0);
        uint256 validatorTokenId = badges.tokenOfOwnerByIndex(validator, 0);

        // Check badge types
        Assert.equal(badges._getBadgeType(clientTokenId), badges.CLIENT_BADGE(), "Should be client badge");
        Assert.equal(badges._getBadgeType(operatorTokenId), badges.OPERATOR_BADGE(), "Should be operator badge");
        Assert.equal(badges._getBadgeType(validatorTokenId), badges.VALIDATOR_BADGE(), "Should be validator badge");
    }
}