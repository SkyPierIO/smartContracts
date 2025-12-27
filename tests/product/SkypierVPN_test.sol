// tests/product/SkypierVPN_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/SkypierVPN.sol";
import "../../contracts/product/tokens/SkypierBadges.sol";
import "../../contracts/lib/ERC6551Registry.sol";
import "../../contracts/lib/TokenBoundAccount.sol";

contract SkypierVPNTest {
    SkypierVPN vpn;
    SkypierBadges badges;
    ERC6551Registry registry;
    TokenBoundAccount tokenBoundAccountImplementation;

    address admin = TestsAccounts.getAccount(0);
    address builder = TestsAccounts.getAccount(1);
    address qa = TestsAccounts.getAccount(2);
    address operator1 = TestsAccounts.getAccount(3);
    address operator2 = TestsAccounts.getAccount(4);
    address paymentPool = TestsAccounts.getAccount(5);

    function beforeAll() public {
        // Deploy registry
        vm.prank(admin);
        registry = new ERC6551Registry();

        // Deploy TokenBoundAccount implementation
        vm.prank(admin);
        tokenBoundAccountImplementation = new TokenBoundAccount(address(0), 0);

        // Deploy SkypierBadges
        vm.prank(admin);
        badges = new SkypierBadges(address(registry), address(tokenBoundAccountImplementation));

        // Deploy SkypierVPN
        vm.prank(admin);
        vpn = new SkypierVPN(address(badges), paymentPool);

        // Grant roles
        vm.prank(admin);
        vpn.grantRole(vpn.BUILDER_ROLE(), builder);
        vm.prank(admin);
        vpn.grantRole(vpn.QA_BADGE(), qa);
        vm.prank(admin);
        badges.grantRole(badges.DEFAULT_ADMIN_ROLE(), admin);
    }

    function testApplyAsOperator() public {
        vm.prank(operator1);
        vpn.applyAsOperator();

        // Check if operator is on waitlist
        bool isOnWaitlist = false;
        for (uint256 i = 0; i < vpn.operatorWaitlist().length; i++) {
            if (vpn.operatorWaitlist()[i] == operator1) {
                isOnWaitlist = true;
                break;
            }
        }

        Assert.ok(isOnWaitlist, "Operator should be on waitlist");
    }

    function testValidateOperator() public {
        // First apply as operator
        vm.prank(operator1);
        vpn.applyAsOperator();

        // Validate the operator
        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
        vm.prank(qa);
        vpn.validateOperator(operator1, peerId);

        // Check node registration
        Assert.ok(vpn.isValidatedOperator(operator1), "Operator should be validated");
        Assert.equal(vpn.getOperatorPeerId(operator1), peerId, "PeerID should match");

        // Check that operator was removed from waitlist
        bool isOnWaitlist = false;
        for (uint256 i = 0; i < vpn.operatorWaitlist().length; i++) {
            if (vpn.operatorWaitlist()[i] == operator1) {
                isOnWaitlist = true;
                break;
            }
        }

        Assert.ok(!isOnWaitlist, "Operator should be removed from waitlist");
    }

    function testClaimOperatorNFTBadge() public {
        // Apply and validate operator
        vm.prank(operator1);
        vpn.applyAsOperator();

        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
        vm.prank(qa);
        vpn.validateOperator(operator1, peerId);

        // Claim the badge
        vm.prank(operator1);
        vpn.claimOperatorNFTBadge();

        // Check that TokenBoundAccount was set
        address account = vpn.getOperatorTokenBoundAccount(operator1);
        Assert.notEqual(account, address(0), "TokenBoundAccount should be set");
    }

    function testUpdateHeartbeat() public {
        // Apply and validate operator
        vm.prank(operator2);
        vpn.applyAsOperator();

        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco2";
        vm.prank(qa);
        vpn.validateOperator(operator2, peerId);

        // Get initial heartbeat
        uint256 initialHeartbeat = vpn.nodes(operator2).lastHeartbeat;

        // Fast forward time
        vm.warp(block.timestamp + 3600);

        // Update heartbeat
        vm.prank(operator2);
        vpn.updateHeartbeat();

        // Check heartbeat was updated
        uint256 newHeartbeat = vpn.nodes(operator2).lastHeartbeat;
        Assert.greaterThan(newHeartbeat, initialHeartbeat, "Heartbeat should be updated");
    }

    function testRevokeOperator() public {
        // Apply and validate operator
        vm.prank(operator1);
        vpn.applyAsOperator();

        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
        vm.prank(qa);
        vpn.validateOperator(operator1, peerId);

        // Revoke operator
        vm.prank(qa);
        vpn.revokeOperator(operator1);

        // Check operator is revoked
        Assert.ok(!vpn.isValidatedOperator(operator1), "Operator should be revoked");
        Assert.ok(vpn.revokedOperators(operator1), "Operator should be in revoked list");
    }

    function testUnauthorizedValidation() public {
        // Apply as operator
        vm.prank(operator2);
        vpn.applyAsOperator();

        // Try to validate without proper role
        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco2";
        vm.expectRevert("Not authorized");
        vm.prank(operator1);
        vpn.validateOperator(operator2, peerId);
    }

    function testUnauthorizedRevoke() public {
        // Apply and validate operator
        vm.prank(operator1);
        vpn.applyAsOperator();

        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
        vm.prank(qa);
        vpn.validateOperator(operator1, peerId);

        // Try to revoke without proper role
        vm.expectRevert("Not authorized");
        vm.prank(operator2);
        vpn.revokeOperator(operator1);
    }

    function testTokenBoundAccountIntegration() public {
        // Apply and validate operator
        vm.prank(operator1);
        vpn.applyAsOperator();

        string memory peerId = "QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco";
        vm.prank(qa);
        vpn.validateOperator(operator1, peerId);

        // Claim the badge
        vm.prank(operator1);
        vpn.claimOperatorNFTBadge();

        // Get the TokenBoundAccount
        address account = vpn.getOperatorTokenBoundAccount(operator1);

        // Verify the account
        (address tokenContract, uint256 tokenId) = ITokenBoundAccount(account).token();
        Assert.equal(tokenContract, address(badges), "Token contract should match");

        // Send ETH to the account
        vm.deal(address(account), 0.1 ether);

        // Check balance
        Assert.equal(account.balance, 0.1 ether, "Account should have 0.1 ETH");
    }
}