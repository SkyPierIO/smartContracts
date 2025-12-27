// tests/internal/ContributionBadges_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/ContributionBadges.sol";

contract ContributionBadgesTest {
    ContributionBadges badges;
    address admin = TestsAccounts.getAccount(0);
    address builder1 = TestsAccounts.getAccount(1);
    address builder2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        badges = new ContributionBadges();
    }

    function testMintContributionBadges() public {
        vm.prank(admin);
        badges.mintContributionBadges(builder1, 3, 1); // Mint 3 badges of type 1 (Technical Fellow)

        Assert.equal(badges.balanceOf(builder1), 3, "Builder should have 3 badges");
        Assert.ok(badges.hasBadge(builder1, 1), "Builder should have Technical Fellow badge");
    }

    function testBadgeExpiry() public {
        vm.prank(admin);
        badges.mintContributionBadges(builder2, 2, 2); // Mint 2 badges of type 2 (Mentor)

        uint256 expiry = badges.getBadgeExpiry(builder2);
        Assert.greaterThan(expiry, block.timestamp, "Expiry should be in the future");
    }

    function testWalletCap() public {
        vm.prank(admin);
        badges.mintContributionBadges(builder1, 6, 1); // Max allowed

        vm.expectRevert("Exceeds wallet cap");
        vm.prank(admin);
        badges.mintContributionBadges(builder1, 1, 1); // Should fail
    }

    function testSoulboundBehavior() public {
        vm.prank(admin);
        badges.mintContributionBadges(builder1, 1, 1);

        vm.expectRevert("Badges are soulbound");
        vm.prank(builder1);
        badges.transfer(builder2, 1);
    }
}