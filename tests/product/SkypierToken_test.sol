// tests/product/SkypierToken_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/SkypierToken.sol";
import "../UUPSProxyBaseTest.sol";

contract SkypierTokenTest is UUPSProxyBaseTest {
    SkypierToken public skypierToken;
    SkypierToken public newVersion;

    function beforeAll() public override {
        super.beforeAll();

        // Deploy initial version
        skypierToken = new SkypierToken();
        skypierToken.initialize();

        // Deploy new version for upgrade testing
        newVersion = new SkypierToken();
    }

    function testInitialDeployment() public {
        Assert.notEqual(
            address(0),
            address(skypierToken),
            "SkypierToken should be deployed"
        );

        // Test initial state
        Assert.equal(
            admin,
            skypierToken.owner(),
            "Admin should be the owner"
        );

        Assert.equal(
            0,
            skypierToken.totalSupply(),
            "Initial supply should be 0"
        );
    }

    function testTokenMinting() public {
        // Test minting functionality
        vm.prank(admin);
        skypierToken.mint(admin, 1000);

        Assert.equal(
            1000,
            skypierToken.balanceOf(admin),
            "Admin should have 1000 tokens"
        );

        Assert.equal(
            1000,
            skypierToken.totalSupply(),
            "Total supply should be 1000"
        );
    }

    function testUpgradeFunctionality() public {
        // Execute upgrade
        vm.prank(admin);
        skypierToken.upgradeTo(address(newVersion));

        // Verify upgrade
        Assert.equal(
            address(newVersion),
            skypierToken.getImplementation(),
            "Implementation should be updated"
        );
    }

    function testUpgradeAccessControl() public {
        testUpgradeAccessControl(address(skypierToken));
    }

    function testStoragePreservation() public {
        // Mint tokens before upgrade
        vm.prank(admin);
        skypierToken.mint(admin, 1000);

        // Upgrade
        vm.prank(admin);
        skypierToken.upgradeTo(address(newVersion));

        // Verify tokens still exist
        Assert.equal(
            1000,
            skypierToken.balanceOf(admin),
            "Tokens should be preserved after upgrade"
        );

        Assert.equal(
            1000,
            skypierToken.totalSupply(),
            "Total supply should be preserved after upgrade"
        );
    }

    function testFunctionalityAfterUpgrade() public {
        // Upgrade first
        vm.prank(admin);
        skypierToken.upgradeTo(address(newVersion));

        // Test that functions still work
        vm.prank(admin);
        skypierToken.mint(nonAdmin, 500);

        Assert.equal(
            500,
            skypierToken.balanceOf(nonAdmin),
            "Functions should work after upgrade"
        );
    }
}