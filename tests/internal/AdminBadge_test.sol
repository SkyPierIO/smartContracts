// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/AdminBadge.sol";
import "../../contracts/lib/BaseAccessControlledUpgradeableToken.sol";

contract AdminBadgeTest {
    AdminBadge badge;
    address admin = TestsAccounts.getAccount(0);
    address builder = TestsAccounts.getAccount(1);
    address user = TestsAccounts.getAccount(2);

    function beforeAll() public {
        // Deploy and initialize AdminBadge
        vm.prank(admin);
        badge = new AdminBadge();
        vm.prank(admin);
        badge.initialize("https://skypier.io/admin/{id}.json", address(0), 0, admin);
    }

    function testInitialize() public {
        Assert.notEqual(address(badge), address(0), "AdminBadge should be deployed");
    }

    function testMintAdminBadge() public {
        vm.prank(admin);
        badge.mintAdminBadge(user);
        
        Assert.equal(badge.balanceOf(user, 0), 1, "User should have 1 admin badge");
    }

    function testBurnAdminBadge() public {
        vm.prank(admin);
        badge.mintAdminBadge(user);
        
        vm.prank(admin);
        badge.burnAdminBadge(user, 0);
        
        Assert.equal(badge.balanceOf(user, 0), 0, "User should have 0 admin badges after burn");
    }

    function testSoulboundTransfer() public {
        vm.prank(admin);
        badge.mintAdminBadge(user);
        
        // Try to transfer (should fail due to soulbound nature)
        vm.expectRevert("Admin badge is soulbound");
        vm.prank(user);
        badge.safeTransferFrom(user, builder, 0, 1, "");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(badge.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }
}
