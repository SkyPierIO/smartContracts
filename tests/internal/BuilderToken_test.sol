// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/BuilderToken.sol";

contract BuilderTokenTest {
    BuilderToken token;
    address admin = TestsAccounts.getAccount(0);
    address user1 = TestsAccounts.getAccount(1);
    address user2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        token = new BuilderToken();
        vm.prank(admin);
        token.initialize();
    }

    function testInitialize() public {
        Assert.notEqual(address(token), address(0), "BuilderToken should be deployed");
    }

    function testMintBuilderToken() public {
        vm.prank(admin);
        token.mintBuilderToken(user1);
        
        Assert.equal(token.balanceOf(user1, 0), 1, "User should have 1 builder token");
    }

    function testMintMultipleTypes() public {
        vm.prank(admin);
        token.mintBuilderToken(user1);
        
        Assert.equal(token.balanceOf(user1, 0), 1, "Should have BUILDER_BADGE");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(token.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }

    function testUnauthorizedMint() public {
        vm.expectRevert("Not authorized");
        vm.prank(user1);
        token.mintBuilderToken(user2);
    }
}
