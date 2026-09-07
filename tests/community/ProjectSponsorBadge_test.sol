// tests/community/ProjectSponsorBadge_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/community/ProjectSponsorBadge.sol";

contract ProjectSponsorBadgeTest {
    ProjectSponsorBadge badge;
    address admin = TestsAccounts.getAccount(0);
    address sponsor1 = TestsAccounts.getAccount(1);
    address sponsor2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        badge = new ProjectSponsorBadge();
    }

    function testMintSponsorBadge() public {
        vm.prank(admin);
        badge.mintSponsorBadge(sponsor1, "project-1", 52 weeks);

        Assert.equal(badge.balanceOf(sponsor1), 1, "Sponsor should have 1 badge");

        (string memory projectId, uint256 startTime, uint256 endTime, ) =
            badge.getProjectInfo(0);

        Assert.equal(projectId, "project-1", "Project ID should match");
        Assert.ok(badge.isValidBadge(0), "Badge should be valid");
    }

    function testBadgeExpiry() public {
        vm.prank(admin);
        badge.mintSponsorBadge(sponsor2, "project-2", 1); // 1 second duration

        vm.warp(block.timestamp + 2); // Fast forward 2 seconds

        Assert.ok(!badge.isValidBadge(1), "Badge should be expired");
    }

    function testSoulboundBehavior() public {
        vm.prank(admin);
        badge.mintSponsorBadge(sponsor1, "project-3", 52 weeks);

        vm.expectRevert("Sponsor badge is soulbound");
        vm.prank(sponsor1);
        badge.safeTransferFrom(sponsor1, sponsor2, 0, 1, "");
    }
}