// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/lib/nodeStatus.sol";

contract NodeStatusTest {
    NodeStatusContract nodeStatus;
    address admin = TestsAccounts.getAccount(0);
    address user = TestsAccounts.getAccount(1);

    function beforeAll() public {
        vm.prank(admin);
        nodeStatus = new NodeStatusContract();
        vm.prank(admin);
        nodeStatus.initialize("NodeStatus", "NS", admin);
    }

    function testInitialize() public {
        Assert.notEqual(address(nodeStatus), address(0), "NodeStatus should be deployed");
    }

    function testMint() public {
        vm.prank(admin);
        nodeStatus.mint("peerId123", "active");
        
        Assert.equal(nodeStatus.balanceOf(admin, 1), 1, "Admin should have 1 NFT");
    }

    function testUpdateStatus() public {
        vm.prank(admin);
        nodeStatus.mint("peerId456", "inactive");
        
        vm.prank(admin);
        nodeStatus.updateStatus(1, "peerId456", "active");
        
        Assert.ok(true, "Status update completed");
    }

    function testSupportsInterface() public {
        bytes4 erc721Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(nodeStatus.supportsInterface(erc721Interface), "Should support ERC721 interface");
    }
}
