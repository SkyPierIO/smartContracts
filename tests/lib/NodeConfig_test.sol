// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/lib/nodeConfig.sol";

contract NodeConfigTest {
    NodeConfigContract nodeConfig;
    address admin = TestsAccounts.getAccount(0);
    address user = TestsAccounts.getAccount(1);

    function beforeAll() public {
        vm.prank(admin);
        nodeConfig = new NodeConfigContract();
        vm.prank(admin);
        nodeConfig.initialize("NodeConfig", "NC");
    }

    function testInitialize() public {
        Assert.notEqual(address(nodeConfig), address(0), "NodeConfig should be deployed");
    }

    function testUpdateNodeConfig() public {
        vm.prank(admin);
        string memory newConfig = '{"cpu": 8, "memory": 16}';
        nodeConfig.updateNodeConfig(1, newConfig);
        
        Assert.equal(nodeConfig.nodeConfig(1), newConfig, "Node config should be updated");
    }

    function testSupportsInterface() public {
        bytes4 erc721Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(nodeConfig.supportsInterface(erc721Interface), "Should support ERC721 interface");
    }
}
