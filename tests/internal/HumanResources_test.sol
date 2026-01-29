// tests/internal/HumanResources_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/internal/HumanResources.sol";

contract HumanResourcesTest {
    HumanResources hr;
    address admin = TestsAccounts.getAccount(0);

    function beforeAll() public {
        vm.prank(admin);
        hr = new HumanResources();
    }

    function testDeployed() public {
        Assert.notEqual(address(hr), address(0), "HumanResources should be deployed");
    }
}
