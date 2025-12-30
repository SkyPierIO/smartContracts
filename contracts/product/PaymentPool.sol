// contracts/product/PaymentPool.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IClientToken.sol";

contract PaymentPool is AccessControl {
    using SafeMath for uint256;

    // Roles
    bytes32 private constant PAYMENT_MANAGER = keccak256("PAYMENT_MANAGER");
    bytes32 private constant BUILDER_ROLE = keccak256("BUILDER_ROLE");

    // Payment intervals
    uint256 public constant BIOWEEKLY_INTERVAL = 14 days;
    uint256 public lastDistributionTime;

    // Wallets
    address payable public networkPool;
    address payable public builderPool;
    address payable public developerPool;

    // Tokens
    IERC20 public skypierToken;
    // address public clientToken;
    IClientToken public clientToken;
    uint256 public paymentAmount; // Amount required to receive CLIENT_BADGE

    // Operator and Validator tracking
    struct Participant {
        address payable wallet;
        uint256 lastPayment;
        uint256 totalContribution;
        bool isActive;
    }

    mapping(address => Participant) public operators;
    mapping(address => Participant) public validators;
    mapping(address => Participant) public builders;

    // Payment metrics
    uint256 public totalNetworkPayments;
    uint256 public totalBuilderPayments;
    uint256 public totalClientDeposits;

    // Events
    event PaymentDistributed(address indexed recipient, uint256 amount, string role);
    event ClientDeposit(address indexed client, uint256 amount);
    event FundsWithdrawn(address indexed wallet, uint256 amount, string walletType);

    constructor(
        address _skypierToken,
        address _clientToken,
        address payable _networkPool,
        address payable _builderPool,
        address payable _developerPool
    ) {
        skypierToken = IERC20(_skypierToken);
        clientToken = IERC1155(_clientToken);
        networkPool = _networkPool;
        builderPool = _builderPool;
        developerPool = _developerPool;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAYMENT_MANAGER, msg.sender);
        lastDistributionTime = block.timestamp;
    }

    // --- Events ---
    event ClientBadgeIssued(address indexed user, uint256 amount);

    constructor(
        address _clientToken,
        address _paymentToken,
        uint256 _paymentAmount
    ) {
        clientToken = IClientToken(_clientToken);
        paymentToken = IERC20(_paymentToken);
        paymentAmount = _paymentAmount;
    }

    /**
     * @dev Pay to receive a CLIENT_BADGE (called by users).
     */
    function payForAccess() external {
        require(
            IERC20(paymentToken).transferFrom(msg.sender, address(this), paymentAmount),
            "Payment failed"
        );

        // Issue CLIENT_BADGE (no expiry)
        clientToken.issueBadge(msg.sender, clientToken.CLIENT_BADGE(), 1, 0);

        emit ClientBadgeIssued(msg.sender, paymentAmount);
    }

    /**
     * @dev Deposit client payments to the payment pool
     * @param amount Amount of client tokens to deposit
     */
    function depositClientPayment(uint256 amount) external {
        require(clientToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        totalClientDeposits = totalClientDeposits.add(amount);
        emit ClientDeposit(msg.sender, amount);
    }

    /**
     * @dev Register an operator for payments
     * @param _operator Address of the operator
     */
    function registerOperator(address payable _operator) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        operators[_operator] = Participant({
            wallet: _operator,
            lastPayment: 0,
            totalContribution: 0,
            isActive: true
        });
    }

    /**
     * @dev Register a validator for payments
     * @param _validator Address of the validator
     */
    function registerValidator(address payable _validator) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        validators[_validator] = Participant({
            wallet: _validator,
            lastPayment: 0,
            totalContribution: 0,
            isActive: true
        });
    }

    /**
     * @dev Register a builder for payments
     * @param _builder Address of the builder
     */
    function registerBuilder(address payable _builder) external {
        require(hasRole(BUILDER_ROLE, msg.sender) || hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        builders[_builder] = Participant({
            wallet: _builder,
            lastPayment: 0,
            totalContribution: 0,
            isActive: true
        });
    }

    /**
     * @dev Record operator contribution metrics
     * @param _operator Address of the operator
     * @param dataVolume Total data volume handled
     * @param duration Duration of service
     */
    function recordOperatorMetrics(address _operator, uint256 dataVolume, uint256 duration) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(operators[_operator].isActive, "Operator not active");

        // Simple metric: dataVolume * duration as contribution score
        uint256 contribution = dataVolume.mul(duration);
        operators[_operator].totalContribution = operators[_operator].totalContribution.add(contribution);
    }

    /**
     * @dev Record validator contribution metrics
     * @param _validator Address of the validator
     * @param validationCount Number of validations performed
     */
    function recordValidatorMetrics(address _validator, uint256 validationCount) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(validators[_validator].isActive, "Validator not active");

        validators[_validator].totalContribution = validators[_validator].totalContribution.add(validationCount);
    }

    /**
     * @dev Record builder contribution metrics
     * @param _builder Address of the builder
     * @param contributionScore Contribution score
     */
    function recordBuilderMetrics(address _builder, uint256 contributionScore) external {
        require(hasRole(BUILDER_ROLE, msg.sender) || hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(builders[_builder].isActive, "Builder not active");

        builders[_builder].totalContribution = builders[_builder].totalContribution.add(contributionScore);
    }

    /**
     * @dev Distribute payments to operators and validators from network pool
     */
    function distributeNetworkPayments() external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(block.timestamp >= lastDistributionTime.add(BIOWEEKLY_INTERVAL), "Too soon for distribution");

        uint256 networkPoolBalance = address(networkPool).balance;
        require(networkPoolBalance > 0, "Insufficient funds in network pool");

        // Calculate total contributions
        uint256 totalOperatorContributions = 0;
        uint256 totalValidatorContributions = 0;
        address[] memory activeOperators = new address[](operatorsKeys.length);
        address[] memory activeValidators = new address[](validatorsKeys.length);

        // Get all active operators and sum their contributions
        for (uint256 i = 0; i < operatorsKeys.length; i++) {
            address operator = operatorsKeys[i];
            if (operators[operator].isActive) {
                totalOperatorContributions = totalOperatorContributions.add(operators[operator].totalContribution);
                activeOperators[i] = operator;
            }
        }

        // Get all active validators and sum their contributions
        for (uint256 i = 0; i < validatorsKeys.length; i++) {
            address validator = validatorsKeys[i];
            if (validators[validator].isActive) {
                totalValidatorContributions = totalValidatorContributions.add(validators[validator].totalContribution);
                activeValidators[i] = validator;
            }
        }

        // Allocate 70% to operators, 30% to validators
        uint256 operatorAllocation = networkPoolBalance.mul(70).div(100);
        uint256 validatorAllocation = networkPoolBalance.sub(operatorAllocation);

        // Distribute to operators
        if (totalOperatorContributions > 0 && activeOperators.length > 0) {
            for (uint256 i = 0; i < activeOperators.length; i++) {
                address operator = activeOperators[i];
                if (operators[operator].isActive) {
                    uint256 share = operatorAllocation.mul(operators[operator].totalContribution).div(totalOperatorContributions);
                    if (share > 0) {
                        operators[operator].lastPayment = block.timestamp;
                        operators[operator].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(operator).transfer(share);
                        emit PaymentDistributed(operator, share, "Operator");

                        totalNetworkPayments = totalNetworkPayments.add(share);
                    }
                }
            }
        }

        // Distribute to validators
        if (totalValidatorContributions > 0 && activeValidators.length > 0) {
            for (uint256 i = 0; i < activeValidators.length; i++) {
                address validator = activeValidators[i];
                if (validators[validator].isActive) {
                    uint256 share = validatorAllocation.mul(validators[validator].totalContribution).div(totalValidatorContributions);
                    if (share > 0) {
                        validators[validator].lastPayment = block.timestamp;
                        validators[validator].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(validator).transfer(share);
                        emit PaymentDistributed(validator, share, "Validator");

                        totalNetworkPayments = totalNetworkPayments.add(share);
                    }
                }
            }
        }

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Distribute payments to builders from builder pool
     */
    function distributeBuilderPayments() external {
        require(hasRole(BUILDER_ROLE, msg.sender) || hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(block.timestamp >= lastDistributionTime.add(BIOWEEKLY_INTERVAL), "Too soon for distribution");

        uint256 builderPoolBalance = address(builderPool).balance;
        require(builderPoolBalance > 0, "Insufficient funds in builder pool");

        // Calculate total contributions
        uint256 totalBuilderContributions = 0;
        address[] memory activeBuilders = new address[](buildersKeys.length);

        // Get all active builders and sum their contributions
        for (uint256 i = 0; i < buildersKeys.length; i++) {
            address builder = buildersKeys[i];
            if (builders[builder].isActive) {
                totalBuilderContributions = totalBuilderContributions.add(builders[builder].totalContribution);
                activeBuilders[i] = builder;
            }
        }

        // Distribute to builders based on contribution
        if (totalBuilderContributions > 0 && activeBuilders.length > 0) {
            for (uint256 i = 0; i < activeBuilders.length; i++) {
                address builder = activeBuilders[i];
                if (builders[builder].isActive) {
                    uint256 share = builderPoolBalance.mul(builders[builder].totalContribution).div(totalBuilderContributions);
                    if (share > 0) {
                        builders[builder].lastPayment = block.timestamp;
                        builders[builder].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(builder).transfer(share);
                        emit PaymentDistributed(builder, share, "Builder");

                        totalBuilderPayments = totalBuilderPayments.add(share);
                    }
                }
            }
        }

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Withdraw funds from a specific wallet
     * @param walletType Type of wallet to withdraw from (network, builder, developer)
     * @param amount Amount to withdraw
     * @param to Address to send funds to
     */
    function withdrawFunds(string memory walletType, uint256 amount, address payable to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");

        address payable wallet;
        if (keccak256(bytes(walletType)) == keccak256(bytes("network"))) {
            wallet = networkPool;
        } else if (keccak256(bytes(walletType)) == keccak256(bytes("builder"))) {
            wallet = builderPool;
        } else if (keccak256(bytes(walletType)) == keccak256(bytes("developer"))) {
            wallet = developerPool;
        } else {
            revert("Invalid wallet type");
        }

        require(address(wallet).balance >= amount, "Insufficient funds");

        // Transfer ETH
        wallet.transfer(amount);
        payable(to).transfer(amount);

        emit FundsWithdrawn(to, amount, walletType);
    }

    /**
     * @dev Deactivate a participant
     * @param participant Address of the participant
     * @param role Role of the participant (operator, validator, builder)
     */
    function deactivateParticipant(address participant, string memory role) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");

        if (keccak256(bytes(role)) == keccak256(bytes("operator"))) {
            operators[participant].isActive = false;
        } else if (keccak256(bytes(role)) == keccak256(bytes("validator"))) {
            validators[participant].isActive = false;
        } else if (keccak256(bytes(role)) == keccak256(bytes("builder"))) {
            require(hasRole(BUILDER_ROLE, msg.sender), "Not authorized");
            builders[participant].isActive = false;
        } else {
            revert("Invalid role");
        }
    }

    /**
     * @dev Reactivate a participant
     * @param participant Address of the participant
     * @param role Role of the participant (operator, validator, builder)
     */
    function reactivateParticipant(address participant, string memory role) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");

        if (keccak256(bytes(role)) == keccak256(bytes("operator"))) {
            operators[participant].isActive = true;
        } else if (keccak256(bytes(role)) == keccak256(bytes("validator"))) {
            validators[participant].isActive = true;
        } else if (keccak256(bytes(role)) == keccak256(bytes("builder"))) {
            require(hasRole(BUILDER_ROLE, msg.sender), "Not authorized");
            builders[participant].isActive = true;
        } else {
            revert("Invalid role");
        }
    }

    /**
     * @dev Internal helper to get all keys from a mapping
     * Note: This is a simplified version - in production you'd need a more efficient approach
     */
    function getMappingKeys(mapping(address => Participant) storage map)
        internal
        view
        returns (address[] memory)
    {
        uint256 size = 0;
        address[] memory keys = new address[](size);

        // In a real implementation, you would need to track keys separately
        // This is a simplified version for demonstration
        return keys;
    }

    // Helper properties to get mapping keys
    address[] public operatorsKeys;
    address[] public validatorsKeys;
    address[] public buildersKeys;

    /**
     * @dev Update the keys for a mapping (called externally for demo purposes)
     */
    function updateMappingKeys(string memory mappingType, address[] memory newKeys) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");

        if (keccak256(bytes(mappingType)) == keccak256(bytes("operators"))) {
            operatorsKeys = newKeys;
        } else if (keccak256(bytes(mappingType)) == keccak256(bytes("validators"))) {
            validatorsKeys = newKeys;
        } else if (keccak256(bytes(mappingType)) == keccak256(bytes("builders"))) {
            buildersKeys = newKeys;
        } else {
            revert("Invalid mapping type");
        }
    }

    /**
     * @dev Fallback receive function to accept ETH
     */
    receive() external payable {
        // Funds can be sent directly to this contract
    }
}