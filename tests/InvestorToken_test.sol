// tests/internal/InvestorToken_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/tokens/InvestorToken.sol";

contract InvestorTokenTest {
    InvestorToken token;
    address admin = TestsAccounts.getAccount(0);
    address investor1 = TestsAccounts.getAccount(1);
    address investor2 = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        token = new InvestorToken();
    }

    function testMintInvestorBadge() public {
        vm.prank(admin);
        token.mintInvestorBadge(investor1, 1000);

        Assert.equal(token.balanceOf(investor1, 0), 1, "Investor should have 1 badge");
        Assert.equal(token.getInvestorAmount(investor1), 1000, "Investor amount should be 1000");
    }

    function testRevokeInvestorBadge() public {
        vm.prank(admin);
        token.mintInvestorBadge(investor2, 500);
        vm.prank(admin);
        token.revokeInvestorBadge(investor2);

        Assert.equal(token.balanceOf(investor2, 0), 0, "Investor should have 0 badges");
    }

    function testUnauthorizedMint() public {
        vm.expectRevert("Not authorized");
        vm.prank(investor1);
        token.mintInvestorBadge(investor2, 100);
    }
}