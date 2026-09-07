// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IClientToken} from "../interfaces/IClientToken.sol";
import {IPaymentPool} from "../interfaces/IPaymentPool.sol";
import {Roles} from "../lib/Roles.sol";

contract PaymentPool is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IPaymentPool {
    // Roles
    bytes32 private constant PAYMENT_MANAGER = keccak256("PAYMENT_MANAGER");
    bytes32 public constant BUILDER_ROLE = Roles.BUILDER_ROLE;

    // Payment intervals
    uint256 public constant BIOWEEKLY_INTERVAL = 14 days;
    uint256 public lastDistributionTime;

    // Wallets
    address payable public networkPool;
    address payable public builderPool;
    address payable public developerPool;

    // Tokens
    address public skypierToken;
    address public paymentToken;
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Events ---
    event ClientBadgeIssued(address indexed user, uint256 amount);

    function initialize(
        address _skypierToken,
        address _clientToken,
        address _paymentToken,
        address payable _networkPool,
        address payable _builderPool,
        address payable _developerPool,
        uint256 _paymentAmount,
        address admin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        skypierToken = _skypierToken;
        clientToken = IClientToken(_clientToken);
        paymentToken = _paymentToken;
        paymentAmount = _paymentAmount;

        networkPool = _networkPool;
        builderPool = _builderPool;
        developerPool = _developerPool;

        _grantRole(DEFAULT_ADMIN_ROLE, admin == address(0) ? msg.sender : admin);
        _grantRole(PAYMENT_MANAGER, admin == address(0) ? msg.sender : admin);
        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Deposit ETH into the contract (IPaymentPool interface implementation)
     */
    function deposit() external payable override {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        // Funds are received directly via this function
    }

    /**
     * @dev Distribute payments to network participants (IPaymentPool interface implementation)
     */
    function distributePayments() external override onlyRole(PAYMENT_MANAGER) {
        // Call the internal distribution functions
        distributeNetworkPayments();
        distributeBuilderPayments();
    }

    /**
     * @dev Get the network pool balance (IPaymentPool interface implementation)
     */
    function getNetworkPoolBalance() external view override returns (uint256) {
        return networkPool != address(0) ? networkPool.balance : 0;
    }

    /**
     * @dev Get the builder pool balance (IPaymentPool interface implementation)
     */
    function getBuilderPoolBalance() external view override returns (uint256) {
        return builderPool != address(0) ? builderPool.balance : 0;
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
        clientToken.mint(msg.sender, clientToken.CLIENT_BADGE(), 1, "");

        emit ClientBadgeIssued(msg.sender, paymentAmount);
    }

    /**
     * @dev Deposit client payments to the payment pool
     * @param amount Amount of client tokens to deposit
     */
    function depositClientPayment(uint256 amount) external {
        require(IERC20(paymentToken).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        totalClientDeposits += amount;
        emit ClientDeposit(msg.sender, amount);
    }

    /**
     * @dev Register an operator for payments
     * @param _operator Address of the operator
     */
    function registerOperator(address payable _operator) external override {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        if (operators[_operator].wallet == address(0)) operatorsKeys.push(_operator);
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
    function registerValidator(address payable _validator) external override {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        if (validators[_validator].wallet == address(0)) validatorsKeys.push(_validator);
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
        if (builders[_builder].wallet == address(0)) buildersKeys.push(_builder);
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
    function recordOperatorMetrics(address _operator, uint256 dataVolume, uint256 duration) external override {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(operators[_operator].isActive, "Operator not active");

        // Simple metric: dataVolume * duration as contribution score
        uint256 contribution = dataVolume * duration;
        operators[_operator].totalContribution = operators[_operator].totalContribution + contribution;
    }

    /**
     * @dev Record validator contribution metrics
     * @param _validator Address of the validator
     * @param validationCount Number of validations performed
     */
    function recordValidatorMetrics(address _validator, uint256 validationCount) external {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(validators[_validator].isActive, "Validator not active");

        validators[_validator].totalContribution = validators[_validator].totalContribution + validationCount;
    }

    /**
     * @dev Record builder contribution metrics
     * @param _builder Address of the builder
     * @param contributionScore Contribution score
     */
    function recordBuilderMetrics(address _builder, uint256 contributionScore) external {
        require(hasRole(BUILDER_ROLE, msg.sender) || hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(builders[_builder].isActive, "Builder not active");

        builders[_builder].totalContribution = builders[_builder].totalContribution + contributionScore;
    }

    /**
     * @dev Distribute payments to operators and validators from network pool
     */
    function distributeNetworkPayments() public {
        require(hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(block.timestamp >= lastDistributionTime + BIOWEEKLY_INTERVAL, "Too soon for distribution");

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
                totalOperatorContributions = totalOperatorContributions + operators[operator].totalContribution;
                activeOperators[i] = operator;
            }
        }

        // Get all active validators and sum their contributions
        for (uint256 i = 0; i < validatorsKeys.length; i++) {
            address validator = validatorsKeys[i];
            if (validators[validator].isActive) {
                totalValidatorContributions = totalValidatorContributions + validators[validator].totalContribution;
                activeValidators[i] = validator;
            }
        }

        // Allocate 70% to operators, 30% to validators
        uint256 operatorAllocation = (networkPoolBalance * 70) / 100;
        uint256 validatorAllocation = networkPoolBalance - operatorAllocation;

        // Distribute to operators
        if (totalOperatorContributions > 0 && activeOperators.length > 0) {
            for (uint256 i = 0; i < activeOperators.length; i++) {
                address operator = activeOperators[i];
                if (operators[operator].isActive) {
                    uint256 share = (operatorAllocation * operators[operator].totalContribution) / totalOperatorContributions;
                    if (share > 0) {
                        operators[operator].lastPayment = block.timestamp;
                        operators[operator].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(operator).transfer(share);
                        emit PaymentDistributed(operator, share, "Operator");

                        totalNetworkPayments = totalNetworkPayments + share;
                    }
                }
            }
        }

        // Distribute to validators
        if (totalValidatorContributions > 0 && activeValidators.length > 0) {
            for (uint256 i = 0; i < activeValidators.length; i++) {
                address validator = activeValidators[i];
                if (validators[validator].isActive) {
                    uint256 share = (validatorAllocation * validators[validator].totalContribution) / totalValidatorContributions;
                    if (share > 0) {
                        validators[validator].lastPayment = block.timestamp;
                        validators[validator].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(validator).transfer(share);
                        emit PaymentDistributed(validator, share, "Validator");

                        totalNetworkPayments = totalNetworkPayments + share;
                    }
                }
            }
        }

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Distribute payments to builders from builder pool
     */
    function distributeBuilderPayments() public {
        require(hasRole(BUILDER_ROLE, msg.sender) || hasRole(PAYMENT_MANAGER, msg.sender), "Not authorized");
        require(block.timestamp >= lastDistributionTime + BIOWEEKLY_INTERVAL, "Too soon for distribution");

        uint256 builderPoolBalance = address(builderPool).balance;
        require(builderPoolBalance > 0, "Insufficient funds in builder pool");

        // Calculate total contributions
        uint256 totalBuilderContributions = 0;
        address[] memory activeBuilders = new address[](buildersKeys.length);

        // Get all active builders and sum their contributions
        for (uint256 i = 0; i < buildersKeys.length; i++) {
            address builder = buildersKeys[i];
            if (builders[builder].isActive) {
                totalBuilderContributions = totalBuilderContributions + builders[builder].totalContribution;
                activeBuilders[i] = builder;
            }
        }

        // Distribute to builders based on contribution
        if (totalBuilderContributions > 0 && activeBuilders.length > 0) {
            for (uint256 i = 0; i < activeBuilders.length; i++) {
                address builder = activeBuilders[i];
                if (builders[builder].isActive) {
                    uint256 share = (builderPoolBalance * builders[builder].totalContribution) / totalBuilderContributions;
                    if (share > 0) {
                        builders[builder].lastPayment = block.timestamp;
                        builders[builder].totalContribution = 0; // Reset for next period

                        // Transfer ETH
                        payable(builder).transfer(share);
                        emit PaymentDistributed(builder, share, "Builder");

                        totalBuilderPayments = totalBuilderPayments + share;
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
    function deactivateParticipant(address participant, string memory role) external override {
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
    function reactivateParticipant(address participant, string memory role) external override {
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
    function getMappingKeys(mapping(address => Participant) storage /*map*/)
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

    // Explicit getters that return the full arrays (for helper tooling)
    function getOperatorsKeys() external view returns (address[] memory) {
        return operatorsKeys;
    }

    function getValidatorsKeys() external view returns (address[] memory) {
        return validatorsKeys;
    }

    function getBuildersKeys() external view returns (address[] memory) {
        return buildersKeys;
    }

    /**
     * @dev Fallback receive function to accept ETH
     */
    receive() external payable {
        // Funds can be sent directly to this contract
    }

    /**
     * @dev UUPS upgrade authorization
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}