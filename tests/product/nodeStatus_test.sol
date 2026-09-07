// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/nodeStatus.sol";
import "UUPSProxyBaseTest.sol";

contract NodeStatusTest is UUPSProxyBaseTest {
    NodeStatus public nodeStatus;
    NodeStatus public newVersion;

    function beforeAll() public override {
        super.beforeAll();

        // Deploy initial version
        nodeStatus = new NodeStatus();
        nodeStatus.initialize();

        // Deploy new version for upgrade testing
        newVersion = new NodeStatus();
    }

    function testInitialDeployment() public {
        Assert.notEqual(
            address(0),
            address(nodeStatus),
            "NodeStatus should be deployed"
        );

        // Test initial state
        Assert.equal(
            admin,
            nodeStatus.owner(),
            "Admin should be the owner"
        );
    }

    function testStatusOperations() public {
        // Test status update
        vm.prank(admin);
        nodeStatus.updateNodeStatus(nonAdmin, true, 100, "healthy");

        (bool isActive, uint256 uptime, string memory status) = nodeStatus.getNodeStatus(nonAdmin);
        Assert.equal(
            true,
            isActive,
            "Node should be active"
        );

        Assert.equal(
            100,
            uptime,
            "Uptime should be set"
        );

        Assert.equal(
            "healthy",
            status,
            "Status should be set"
        );
    }

    function testUpgradeFunctionality() public {
        // Execute upgrade
        vm.prank(admin);
        nodeStatus.upgradeTo(address(newVersion));

        // Verify upgrade
        Assert.equal(
            address(newVersion),
            nodeStatus.getImplementation(),
            "Implementation should be updated"
        );
    }

    function testUpgradeAccessControl() public {
        testUpgradeAccessControl(address(nodeStatus));
    }

    function testStoragePreservation() public {
        // Update status before upgrade
        vm.prank(admin);
        nodeStatus.updateNodeStatus(nonAdmin, true, 100, "healthy");

        // Upgrade
        vm.prank(admin);
        nodeStatus.upgradeTo(address(newVersion));

        // Verify status preserved
        (bool isActive, uint256 uptime, string memory status) = nodeStatus.getNodeStatus(nonAdmin);
        Assert.equal(
            true,
            isActive,
            "Status should be preserved after upgrade"
        );
    }

    function testFunctionalityAfterUpgrade() public {
        // Upgrade first
        vm.prank(admin);
        nodeStatus.upgradeTo(address(newVersion));

        // Test that functions still work
        vm.prank(admin);
        nodeStatus.updateNodeStatus(admin, false, 0, "offline");

        (bool isActive, , ) = nodeStatus.getNodeStatus(admin);
        Assert.equal(
            false,
            isActive,
            "Functions should work after upgrade"
        );
    }
}