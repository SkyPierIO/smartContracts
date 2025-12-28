// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "contracts/product/SkypierVPN.sol";
import "contracts/product/tokens/SkypierBadges.sol";
import "contracts/product/tokens/SkypierToken.sol";

contract ProxyContractTest {
    // Contract instances
    SkypierVPN public skypierVPN;
    SkypierBadges public skypierBadges;
    SkypierToken public skypierToken;

    // Admin account (default: first Remix test account)
    address public proxyAddress;
    address public admin;

    function beforeAll() public {
        admin = TestsAccounts.getAccount(0);

        // Deploy and initialize UUPS contracts
        skypierVPN = new SkypierVPN();
        skypierVPN.initialize();

        skypierBadge = new SkypierBadge();
        skypierBadge.initialize();

        skypierToken = new SkypierToken();
        skypierToken.initialize();
    }

    // Test initial deployment
    function testInitialDeployment() public {
        Assert.notEqual(
            address(0),
            address(skypierVPN),
            "SkypierVPN should be deployed"
        );
        Assert.notEqual(
            address(0),
            address(skypierBadge),
            "SkypierBadge should be deployed"
        );
        Assert.notEqual(
            address(0),
            address(skypierToken),
            "SkypierToken should be deployed"
        );
    }

    // Test upgrade functionality (example for SkypierVPN)
    function testUpgradeSkypierVPN() public {
        // Deploy new version
        SkypierVPN newVersion = new SkypierVPN();

        // Execute upgrade (only admin)
        vm.prank(admin);
        skypierVPN.upgradeTo(address(newVersion));

        // Verify upgrade
        Assert.equal(
            address(newVersion),
            skypierVPN.getImplementation(),
            "Implementation should be updated"
        );
    }

    // Test admin restrictions
    function testUpgradeAccessControl() public {
        address nonAdmin = TestsAccounts.getAccount(1);

        // Should revert when non-admin tries to upgrade
        vm.prank(nonAdmin);
        try skypierVPN.upgradeTo(address(0)) {
            Assert.fail("Upgrade should fail for non-admin");
        } catch {
            Assert.ok(true, "Upgrade correctly reverted for non-admin");
        }
    }

    // Test storage preservation after upgrade
    function testStoragePreservation() public {
        // Set some state
        vm.prank(admin);
        skypierVPN.setSomeValue(42); // Replace with actual function

        // Upgrade
        SkypierVPN newVersion = new SkypierVPN();
        vm.prank(admin);
        skypierVPN.upgradeTo(address(newVersion));

        // Verify state preserved
        Assert.equal(
            42,
            skypierVPN.getSomeValue(), // Replace with actual getter
            "State should be preserved after upgrade"
        );
    }
}