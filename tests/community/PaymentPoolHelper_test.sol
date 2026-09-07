// tests/product/PaymentPoolHelper_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/PaymentPool.sol";
import "../../contracts/product/PaymentPoolHelper.sol";
import "../../contracts/product/tokens/SkypierToken.sol";

contract PaymentPoolHelperTest {
    PaymentPool paymentPool;
    PaymentPoolHelper helper;
    SkypierToken clientToken;
    SkypierToken skypierToken;

    address admin = TestsAccounts.getAccount(0);
    address paymentManager = TestsAccounts.getAccount(1);
    address operator = TestsAccounts.getAccount(2);
    address validator = TestsAccounts.getAccount(3);
    address builder = TestsAccounts.getAccount(4);

    address payable networkPool = payable(TestsAccounts.getAccount(5));
    address payable builderPool = payable(TestsAccounts.getAccount(6));
    address payable developerPool = payable(TestsAccounts.getAccount(7));

    function beforeAll() public {
        // Setup tokens
        vm.prank(admin);
        skypierToken = new SkypierToken();
        vm.prank(admin);
        clientToken = new SkypierToken();

        // Setup payment pool
        vm.prank(admin);
        paymentPool = new PaymentPool(
            address(skypierToken),
            address(clientToken),
            networkPool,
            builderPool,
            developerPool
        );

        // Setup helper
        vm.prank(admin);
        helper = new PaymentPoolHelper(address(paymentPool));

        // Grant roles
        vm.prank(admin);
        paymentPool.grantRole(paymentPool.PAYMENT_MANAGER(), paymentManager);

        // Register participants
        vm.prank(paymentManager);
        paymentPool.registerOperator(operator);
        vm.prank(paymentManager);
        paymentPool.registerValidator(validator);
        vm.prank(paymentManager);
        paymentPool.registerBuilder(builder);

        // Update keys
        address[] memory operatorKeys = new address[](1);
        operatorKeys[0] = operator;

        address[] memory validatorKeys = new address[](1);
        validatorKeys[0] = validator;

        address[] memory builderKeys = new address[](1);
        builderKeys[0] = builder;

        vm.prank(paymentManager);
        helper.updateAllKeys(operatorKeys, validatorKeys, builderKeys);
    }

    function testGetActiveOperators() public {
        address[] memory activeOperators = helper.getActiveOperators();
        Assert.equal(activeOperators.length, 1, "Should have 1 active operator");
        Assert.equal(activeOperators[0], operator, "Operator address should match");
    }

    function testGetActiveValidators() public {
        address[] memory activeValidators = helper.getActiveValidators();
        Assert.equal(activeValidators.length, 1, "Should have 1 active validator");
        Assert.equal(activeValidators[0], validator, "Validator address should match");
    }

    function testGetActiveBuilders() public {
        address[] memory activeBuilders = helper.getActiveBuilders();
        Assert.equal(activeBuilders.length, 1, "Should have 1 active builder");
        Assert.equal(activeBuilders[0], builder, "Builder address should match");
    }

    function testUpdateAllKeys() public {
        address newOperator = TestsAccounts.getAccount(8);
        address newValidator = TestsAccounts.getAccount(9);
        address newBuilder = TestsAccounts.getAccount(10);

        // Register new participants
        vm.prank(paymentManager);
        paymentPool.registerOperator(newOperator);
        vm.prank(paymentManager);
        paymentPool.registerValidator(newValidator);
        vm.prank(paymentManager);
        paymentPool.registerBuilder(newBuilder);

        // Update all keys
        address[] memory operatorKeys = new address[](2);
        operatorKeys[0] = operator;
        operatorKeys[1] = newOperator;

        address[] memory validatorKeys = new address[](2);
        validatorKeys[0] = validator;
        validatorKeys[1] = newValidator;

        address[] memory builderKeys = new address[](2);
        builderKeys[0] = builder;
        builderKeys[1] = newBuilder;

        vm.prank(paymentManager);
        helper.updateAllKeys(operatorKeys, validatorKeys, builderKeys);

        // Verify updates
        address[] memory updatedOperators = helper.getActiveOperators();
        address[] memory updatedValidators = helper.getActiveValidators();
        address[] memory updatedBuilders = helper.getActiveBuilders();

        Assert.equal(updatedOperators.length, 2, "Should have 2 active operators");
        Assert.equal(updatedValidators.length, 2, "Should have 2 active validators");
        Assert.equal(updatedBuilders.length, 2, "Should have 2 active builders");
    }
}