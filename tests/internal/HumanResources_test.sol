// tests/internal/HumanResources_test.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/HumanResources.sol";

contract HumanResourcesTest {
    HumanResources hr;
    address admin = TestsAccounts.getAccount(0);
    address builder = TestsAccounts.getAccount(1);
    address treasurer = TestsAccounts.getAccount(2);
    address payable builderPool = payable(TestsAccounts.getAccount(3));

    function beforeAll() public {
        vm.prank(admin);
        hr = new HumanResources();
        vm.prank(admin);
        hr.initialize(builderPool);
    }

    function testInitialize() public {
        Assert.notEqual(address(hr), address(0), "HumanResources should be deployed");
    }

    function testRegisterBuilder() public {
        uint256 allocation = 1000 ether;
        vm.prank(admin);
        hr.registerBuilder(builder, "developer", allocation);
        
        HumanResources.Builder memory builderInfo = hr.getBuilder(builder);
        Assert.equal(builderInfo.wallet, builder, "Builder wallet should match");
        Assert.equal(builderInfo.monthlyAllocation, allocation, "Allocation should match");
        Assert.ok(builderInfo.isActive, "Builder should be active");
    }

    function testDeregisterBuilder() public {
        uint256 allocation = 1000 ether;
        vm.prank(admin);
        hr.registerBuilder(builder, "developer", allocation);
        
        vm.prank(admin);
        hr.deregisterBuilder(builder);
        
        HumanResources.Builder memory builderInfo = hr.getBuilder(builder);
        Assert.ok(!builderInfo.isActive, "Builder should be inactive after deregister");
    }

    function testUpdateBuilderAllocation() public {
        uint256 allocation = 1000 ether;
        uint256 newAllocation = 2000 ether;
        
        vm.prank(admin);
        hr.registerBuilder(builder, "developer", allocation);
        
        vm.prank(admin);
        hr.updateBuilderAllocation(builder, newAllocation);
        
        HumanResources.Builder memory builderInfo = hr.getBuilder(builder);
        Assert.equal(builderInfo.monthlyAllocation, newAllocation, "Allocation should be updated");
    }

    function testGetActiveBuildersCount() public {
        vm.prank(admin);
        hr.registerBuilder(builder, "developer", 1000 ether);
        
        Assert.equal(hr.getActiveBuildersCount(), 1, "Should have 1 active builder");
    }
}
