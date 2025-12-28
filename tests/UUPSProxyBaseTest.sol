// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// Base test contract with common functionality
contract UUPSProxyBaseTest {
    address public admin;
    address public nonAdmin;

    function beforeAll() public virtual {
        admin = TestsAccounts.getAccount(0);
        nonAdmin = TestsAccounts.getAccount(1);
    }

    // Helper to test upgrade fails for non-admin
    function testUpgradeAccessControl(address contractAddress) internal {
        vm.prank(nonAdmin);
        try UUPSUpgradeable(contractAddress).upgradeTo(address(0)) {
            Assert.fail("Upgrade should fail for non-admin");
        } catch {
            Assert.ok(true, "Upgrade correctly reverted for non-admin");
        }
    }
}