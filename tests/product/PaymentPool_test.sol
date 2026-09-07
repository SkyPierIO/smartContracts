// tests/product/PaymentPool_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/PaymentPool.sol";
import "../../contracts/product/tokens/SkypierToken.sol";

contract PaymentPoolTest {
    PaymentPool paymentPool;
    SkypierToken clientToken;
    SkypierToken skypierToken;

    address admin = TestsAccounts.getAccount(0);
    address paymentManager = TestsAccounts.getAccount(1);
    address builder = TestsAccounts.getAccount(2);
    address operator = TestsAccounts.getAccount(3);
    address validator = TestsAccounts.getAccount(4);
    address client = TestsAccounts.getAccount(5);

    address payable networkPool = payable(TestsAccounts.getAccount(6));
    address payable builderPool = payable(TestsAccounts.getAccount(7));
    address payable developerPool = payable(TestsAccounts.getAccount(8));

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

        // Grant roles
        vm.prank(admin);
        paymentPool.grantRole(paymentPool.PAYMENT_MANAGER(), paymentManager);
        vm.prank(admin);
        paymentPool.grantRole(paymentPool.BUILDER_ROLE(), builder);

        // Fund pools
        vm.deal(networkPool, 100 ether);
        vm.deal(builderPool, 50 ether);
        vm.deal(developerPool, 25 ether);

        // Mint tokens to client
        vm.prank(admin);
        clientToken.mint(client, 1000);
        vm.prank(client);
        clientToken.approve(address(paymentPool), 1000);
    }

    function testClientDeposit() public {
        vm.prank(client);
        paymentPool.depositClientPayment(500);

        Assert.equal(clientToken.balanceOf(address(paymentPool)), 500, "Payment pool should have 500 client tokens");
        Assert.equal(paymentPool.totalClientDeposits(), 500, "Total client deposits should be 500");
    }

    function testRegisterParticipants() public {
        // Register operator
        vm.prank(paymentManager);
        paymentPool.registerOperator(operator);

        // Register validator
        vm.prank(paymentManager);
        paymentPool.registerValidator(validator);

        // Register builder
        vm.prank(builder);
        paymentPool.registerBuilder(builder);

        // Check registrations
        Assert.ok(paymentPool.operators(operator).isActive, "Operator should be active");
        Assert.ok(paymentPool.validators(validator).isActive, "Validator should be active");
        Assert.ok(paymentPool.builders(builder).isActive, "Builder should be active");
    }

    function testRecordMetrics() public {
        // Record operator metrics
        vm.prank(paymentManager);
        paymentPool.recordOperatorMetrics(operator, 1000, 100); // 1000 data volume, 100 duration

        // Record validator metrics
        vm.prank(paymentManager);
        paymentPool.recordValidatorMetrics(validator, 50); // 50 validations

        // Record builder metrics
        vm.prank(builder);
        paymentPool.recordBuilderMetrics(builder, 200); // 200 contribution score

        // Check metrics
        Assert.equal(paymentPool.operators(operator).totalContribution, 100000, "Operator contribution should be 100000");
        Assert.equal(paymentPool.validators(validator).totalContribution, 50, "Validator contribution should be 50");
        Assert.equal(paymentPool.builders(builder).totalContribution, 200, "Builder contribution should be 200");
    }

    function testUpdateMappingKeys() public {
        address[] memory operatorKeys = new address[](1);
        operatorKeys[0] = operator;

        address[] memory validatorKeys = new address[](1);
        validatorKeys[0] = validator;

        address[] memory builderKeys = new address[](1);
        builderKeys[0] = builder;

        vm.prank(paymentManager);
        paymentPool.updateMappingKeys("operators", operatorKeys);
        vm.prank(paymentManager);
        paymentPool.updateMappingKeys("validators", validatorKeys);
        vm.prank(paymentManager);
        paymentPool.updateMappingKeys("builders", builderKeys);
    }

    function testDistributeNetworkPayments() public {
        // Set up keys first
        testUpdateMappingKeys();

        // Fast forward 15 days to allow distribution
        vm.warp(block.timestamp + 15 days);

        // Fund network pool
        uint256 initialBalance = networkPool.balance;
        vm.deal(networkPool, 10 ether);

        // Distribute payments
        vm.prank(paymentManager);
        paymentPool.distributeNetworkPayments();

        // Check that funds were distributed
        Assert.lesserThan(networkPool.balance, initialBalance, "Network pool balance should decrease");

        // Check that total payments increased
        Assert.greaterThan(paymentPool.totalNetworkPayments(), 0, "Total network payments should be > 0");
    }

    function testDistributeBuilderPayments() public {
        // Fast forward 15 days to allow distribution
        vm.warp(block.timestamp + 15 days);

        // Fund builder pool
        uint256 initialBalance = builderPool.balance;
        vm.deal(builderPool, 5 ether);

        // Distribute payments
        vm.prank(builder);
        paymentPool.distributeBuilderPayments();

        // Check that funds were distributed
        Assert.lesserThan(builderPool.balance, initialBalance, "Builder pool balance should decrease");

        // Check that total payments increased
        Assert.greaterThan(paymentPool.totalBuilderPayments(), 0, "Total builder payments should be > 0");
    }

    function testWithdrawFunds() public {
        // Initial balance
        uint256 initialBalance = address(paymentPool).balance;
        vm.deal(address(paymentPool), 10 ether);

        // Withdraw from network pool
        vm.prank(admin);
        paymentPool.withdrawFunds("network", 5 ether, admin);

        // Check balance changes
        Assert.equal(address(paymentPool).balance, initialBalance + 5 ether, "Contract balance should increase by 5 ETH");
    }

    function testDeactivateParticipant() public {
        vm.prank(paymentManager);
        paymentPool.deactivateParticipant(operator, "operator");

        Assert.ok(!paymentPool.operators(operator).isActive, "Operator should be inactive");
    }

    function testUnauthorizedAccess() public {
        // Try to register operator without permission
        vm.expectRevert("Not authorized");
        vm.prank(client);
        paymentPool.registerOperator(client);

        // Try to distribute payments too soon
        vm.expectRevert("Too soon for distribution");
        vm.prank(paymentManager);
        paymentPool.distributeNetworkPayments();
    }
}