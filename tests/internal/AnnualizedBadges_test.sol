// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/AnnualizedBadges.sol";

contract AnnualizedBadgesTest {
    AnnualizedBadges badge;
    address admin = TestsAccounts.getAccount(0);
    address user1 = TestsAccounts.getAccount(1);
    address user2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        badge = new AnnualizedBadges();
        vm.prank(admin);
        badge.initialize(
            "https://skypier.io/annualized/{id}.json",
            address(0),
            0,
            admin
        );
    }

    function testInitialize() public {
        Assert.notEqual(address(badge), address(0), "AnnualizedBadges should be deployed");
    }

    function testAwardBadge() public {
        vm.prank(admin);
        badge.awardBadge(user1, 0); // TECHNICAL_FELLOW_BADGE
        
        Assert.ok(badge.hasBadge(user1, 0), "User should have TECHNICAL_FELLOW_BADGE");
    }

    function testGetBadgeExpiry() public {
        vm.prank(admin);
        badge.awardBadge(user1, 1); // MENTOR_BADGE
        
        uint256 expiry = badge.getBadgeExpiry(user1, 1);
        Assert.greaterThan(expiry, block.timestamp, "Expiry should be in the future");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(badge.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }
}
