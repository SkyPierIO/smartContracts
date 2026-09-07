// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/ClientToken.sol";

contract ClientTokenTest {
    ClientToken token;
    address admin = TestsAccounts.getAccount(0);
    address minter = TestsAccounts.getAccount(1);
    address client = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        token = new ClientToken();
        vm.prank(admin);
        token.initialize(minter, admin);
    }

    function testInitialize() public {
        Assert.notEqual(address(token), address(0), "ClientToken should be deployed");
    }

    function testMint() public {
        vm.prank(minter);
        token.mint(client, 0, 1, "Client badge metadata");
        
        Assert.equal(token.balanceOf(client, 0), 1, "Client should have 1 badge");
    }

    function testBurn() public {
        vm.prank(minter);
        token.mint(client, 0, 1, "Client badge metadata");
        
        vm.prank(admin);
        token.burn(client, 0, 1);
        
        Assert.equal(token.balanceOf(client, 0), 0, "Client should have 0 badges after burn");
    }

    function testSetExpiry() public {
        vm.prank(minter);
        token.mint(client, 0, 1, "Client badge metadata");
        
        uint64 expiryTime = uint64(block.timestamp + 30 days);
        vm.prank(admin);
        token.setExpiry(0, expiryTime);
        
        Assert.ok(!token.isExpired(0), "Token should not be expired");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        bytes4 erc2981Interface = bytes4(keccak256("royaltyInfo(uint256,uint256)"));
        Assert.ok(token.supportsInterface(erc1155Interface), "Should support ERC1155");
        Assert.ok(token.supportsInterface(erc2981Interface), "Should support ERC2981");
    }
}
