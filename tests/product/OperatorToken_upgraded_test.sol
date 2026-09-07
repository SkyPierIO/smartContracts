// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/OperatorToken.sol";

contract OperatorTokenTest {
    OperatorToken token;
    address admin = TestsAccounts.getAccount(0);
    address operator = TestsAccounts.getAccount(1);
    address other = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        token = new OperatorToken();
        vm.prank(admin);
        token.initialize();
    }

    function testInitialize() public {
        Assert.notEqual(address(token), address(0), "OperatorToken should be deployed");
    }

    function testMintOperator() public {
        vm.prank(admin);
        uint256 tokenId = token.mint(operator, "node-123");
        
        Assert.equal(token.balanceOf(operator, tokenId), 1, "Operator should have 1 token");
    }

    function testDeregisterOperator() public {
        vm.prank(admin);
        uint256 tokenId = token.mint(operator, "node-456");
        
        vm.prank(admin);
        token.deregisterOperator(tokenId);
        
        Assert.equal(token.totalSupply(tokenId), 0, "Token supply should be 0 after deregister");
    }

    function testSoulbound() public {
        vm.prank(admin);
        uint256 tokenId = token.mint(operator, "node-789");
        
        vm.expectRevert("OperatorToken is soulbound");
        vm.prank(operator);
        token.safeTransferFrom(operator, other, tokenId, 1, "");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(token.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }
}
