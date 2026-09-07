// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/product/tokens/OperatorToken.sol";
import "UUPSProxyBaseTest.sol";

contract HostContractTest is UUPSProxyBaseTest {
    HostContract public hostContract;
    HostContract public newVersion;

    function beforeAll() public override {
        super.beforeAll();

        // Deploy initial version
        hostContract = new HostContract();
        hostContract.initialize();

        // Deploy new version for upgrade testing
        newVersion = new HostContract();
    }

    function testInitialDeployment() public {
        Assert.notEqual(
            address(0),
            address(hostContract),
            "HostContract should be deployed"
        );

        // Test initial state
        Assert.equal(
            admin,
            hostContract.owner(),
            "Admin should be the owner"
        );
    }

    function testHostRegistration() public {
        // Test host registration functionality
        vm.prank(admin);
        hostContract.registerHost(nonAdmin, "test-host", 100);

        (string memory hostname, uint256 capacity) = hostContract.getHostInfo(nonAdmin);
        Assert.equal(
            "test-host",
            hostname,
            "Host should be registered"
        );

        Assert.equal(
            100,
            capacity,
            "Capacity should be set"
        );
    }

    function testUpgradeFunctionality() public {
        // Execute upgrade
        vm.prank(admin);
        hostContract.upgradeTo(address(newVersion));

        // Verify upgrade
        Assert.equal(
            address(newVersion),
            hostContract.getImplementation(),
            "Implementation should be updated"
        );
    }

    function testUpgradeAccessControl() public {
        testUpgradeAccessControl(address(hostContract));
    }

    function testStoragePreservation() public {
        // Register host before upgrade
        vm.prank(admin);
        hostContract.registerHost(nonAdmin, "test-host", 100);

        // Upgrade
        vm.prank(admin);
        hostContract.upgradeTo(address(newVersion));

        // Verify host info preserved
        (string memory hostname, uint256 capacity) = hostContract.getHostInfo(nonAdmin);
        Assert.equal(
            "test-host",
            hostname,
            "Host info should be preserved after upgrade"
        );

        Assert.equal(
            100,
            capacity,
            "Capacity should be preserved after upgrade"
        );
    }

    function testFunctionalityAfterUpgrade() public {
        // Upgrade first
        vm.prank(admin);
        hostContract.upgradeTo(address(newVersion));

        // Test that functions still work
        vm.prank(admin);
        hostContract.registerHost(admin, "new-host", 200);

        (string memory hostname, uint256 capacity) = hostContract.getHostInfo(admin);
        Assert.equal(
            "new-host",
            hostname,
            "Functions should work after upgrade"
        );
    }
}