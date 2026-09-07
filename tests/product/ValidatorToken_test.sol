// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/ValidatorToken.sol";

contract ValidatorTokenTest {
    ValidatorToken token;
    address admin = TestsAccounts.getAccount(0);
    address validator = TestsAccounts.getAccount(1);
    address other = TestsAccounts.getAccount(2);

    function beforeAll() public {
        vm.prank(admin);
        token = new ValidatorToken();
        vm.prank(admin);
        token.initialize();
    }

    function testInitialize() public {
        Assert.notEqual(address(token), address(0), "ValidatorToken should be deployed");
    }

    function testMintValidatorBadge() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(admin);
        token.mintValidatorBadge(validator, stakeAmount);
        
        Assert.equal(token.balanceOf(validator, 0), 1, "Validator should have 1 badge");
    }

    function testGetValidatorInfo() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(admin);
        token.mintValidatorBadge(validator, stakeAmount);
        
        ValidatorToken.ValidatorInfo memory info = token.getValidatorInfo(validator);
        Assert.equal(info.validatorAddress, validator, "Validator address should match");
        Assert.equal(info.stakingAmount, stakeAmount, "Staking amount should match");
        Assert.ok(info.isActive, "Validator should be active");
    }

    function testRevokeValidatorBadge() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(admin);
        token.mintValidatorBadge(validator, stakeAmount);
        
        vm.prank(admin);
        token.revokeValidatorBadge(validator);
        
        Assert.equal(token.balanceOf(validator, 0), 0, "Validator should have 0 badges after revoke");
    }

    function testSoulbound() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(admin);
        token.mintValidatorBadge(validator, stakeAmount);
        
        vm.expectRevert("Validator token is soulbound");
        vm.prank(validator);
        token.safeTransferFrom(validator, other, 0, 1, "");
    }

    function testSupportsInterface() public {
        bytes4 erc1155Interface = bytes4(keccak256("supportsInterface(bytes4)"));
        Assert.ok(token.supportsInterface(erc1155Interface), "Should support ERC1155 interface");
    }
}
