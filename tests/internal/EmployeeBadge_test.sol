// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/EmployeeBadge.sol";

contract EmployeeBadgeTest {
    EmployeeLevelBadge badge;
    address admin = TestsAccounts.getAccount(0);
    address user1 = TestsAccounts.getAccount(1);
    address user2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        badge = new EmployeeLevelBadge();
        vm.prank(admin);
        badge.initialize(
            "https://skypier.io/employee/{id}.json",
            address(0),
            0,
            30 days,
            admin
        );
    }

    function testInitialize() public {
        Assert.notEqual(address(badge), address(0), "EmployeeBadge should be deployed");
    }

    function testSetDefaultExpiryDuration() public {
        vm.prank(admin);
        badge.setDefaultExpiryDuration(60 days);
        
        Assert.equal(badge.expiryDuration(), 60 days, "Expiry duration should be updated");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(badge.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }
}
