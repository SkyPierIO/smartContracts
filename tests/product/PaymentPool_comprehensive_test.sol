// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/PaymentPool.sol";

contract PaymentPoolTest {
    PaymentPool pool;
    address admin = TestsAccounts.getAccount(0);
    address operator = TestsAccounts.getAccount(1);
    address validator = TestsAccounts.getAccount(2);
    address builder = TestsAccounts.getAccount(3);
    address payable networkPool = payable(TestsAccounts.getAccount(4));
    address payable builderPoolAddr = payable(TestsAccounts.getAccount(5));
    address payable developerPool = payable(TestsAccounts.getAccount(6));

    function beforeAll() public {
        vm.prank(admin);
        pool = new PaymentPool();
        vm.prank(admin);
        pool.initialize(
            address(0),
            address(0),
            address(0),
            networkPool,
            builderPoolAddr,
            developerPool,
            1 ether,
            admin
        );
    }

    function testInitialize() public {
        Assert.notEqual(address(pool), address(0), "PaymentPool should be deployed");
    }

    function testRegisterOperator() public {
        vm.prank(admin);
        pool.registerOperator(payable(operator));
        
        PaymentPool.Participant memory opInfo = pool.operators(operator);
        Assert.equal(opInfo.wallet, operator, "Operator wallet should match");
        Assert.ok(opInfo.isActive, "Operator should be active");
    }

    function testRegisterValidator() public {
        vm.prank(admin);
        pool.registerValidator(payable(validator));
        
        PaymentPool.Participant memory valInfo = pool.validators(validator);
        Assert.equal(valInfo.wallet, validator, "Validator wallet should match");
        Assert.ok(valInfo.isActive, "Validator should be active");
    }

    function testRegisterBuilder() public {
        vm.prank(admin);
        pool.registerBuilder(payable(builder));
        
        PaymentPool.Participant memory bldrInfo = pool.builders(builder);
        Assert.equal(bldrInfo.wallet, builder, "Builder wallet should match");
        Assert.ok(bldrInfo.isActive, "Builder should be active");
    }

    function testDeactivateParticipant() public {
        vm.prank(admin);
        pool.registerOperator(payable(operator));
        
        vm.prank(admin);
        pool.deactivateParticipant(operator, "operator");
        
        PaymentPool.Participant memory opInfo = pool.operators(operator);
        Assert.ok(!opInfo.isActive, "Operator should be inactive");
    }

    function testReactivateParticipant() public {
        vm.prank(admin);
        pool.registerOperator(payable(operator));
        
        vm.prank(admin);
        pool.deactivateParticipant(operator, "operator");
        
        vm.prank(admin);
        pool.reactivateParticipant(operator, "operator");
        
        PaymentPool.Participant memory opInfo = pool.operators(operator);
        Assert.ok(opInfo.isActive, "Operator should be active again");
    }
}
