// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/nodeConfig.sol";
import "UUPSProxyBaseTest.sol";

contract NodeConfigTest is UUPSProxyBaseTest {
    NodeConfig public nodeConfig;
    NodeConfig public newVersion;

    function beforeAll() public override {
        super.beforeAll();

        // Deploy initial version
        nodeConfig = new NodeConfig();
        nodeConfig.initialize();

        // Deploy new version for upgrade testing
        newVersion = new NodeConfig();
    }

    function testInitialDeployment() public {
        Assert.notEqual(
            address(0),
            address(nodeConfig),
            "NodeConfig should be deployed"
        );

        // Test initial state
        Assert.equal(
            admin,
            nodeConfig.owner(),
            "Admin should be the owner"
        );
    }

    function testConfigOperations() public {
        // Test config setting
        vm.prank(admin);
        nodeConfig.setConfigParameter("test-key", "test-value");

        string memory value = nodeConfig.getConfigParameter("test-key");
        Assert.equal(
            "test-value",
            value,
            "Config parameter should be set"
        );
    }

    function testUpgradeFunctionality() public {
        // Execute upgrade
        vm.prank(admin);
        nodeConfig.upgradeTo(address(newVersion));

        // Verify upgrade
        Assert.equal(
            address(newVersion),
            nodeConfig.getImplementation(),
            "Implementation should be updated"
        );
    }

    function testUpgradeAccessControl() public {
        testUpgradeAccessControl(address(nodeConfig));
    }

    function testStoragePreservation() public {
        // Set config before upgrade
        vm.prank(admin);
        nodeConfig.setConfigParameter("test-key", "test-value");

        // Upgrade
        vm.prank(admin);
        nodeConfig.upgradeTo(address(newVersion));

        // Verify config preserved
        string memory value = nodeConfig.getConfigParameter("test-key");
        Assert.equal(
            "test-value",
            value,
            "Config should be preserved after upgrade"
        );
    }

    function testFunctionalityAfterUpgrade() public {
        // Upgrade first
        vm.prank(admin);
        nodeConfig.upgradeTo(address(newVersion));

        // Test that functions still work
        vm.prank(admin);
        nodeConfig.setConfigParameter("new-key", "new-value");

        string memory value = nodeConfig.getConfigParameter("new-key");
        Assert.equal(
            "new-value",
            value,
            "Functions should work after upgrade"
        );
    }
}