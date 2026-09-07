// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ISkypierVPN} from "../interfaces/ISkypierVPN.sol";
import {IPaymentPool} from "../interfaces/IPaymentPool.sol";
import {IClientToken} from "../interfaces/IClientToken.sol";
import {Roles} from "../lib/Roles.sol";
import {SkypierBadges} from "./tokens/SkypierBadges.sol";
import {SkypierToken} from "./tokens/SkypierToken.sol";
import {OperatorToken} from "./tokens/OperatorToken.sol";
import {ValidatorToken} from "./tokens/ValidatorToken.sol";
import {ERC6551Registry} from "../lib/ERC6551Registry.sol";
import {TokenBoundAccount} from "../lib/TokenBoundAccount.sol";

/**
 * @title SkypierVPN
 * @dev Coordinates persona onboarding, node lifecycle, badges, and payments.
 */
contract SkypierVPN is Initializable, AccessControlUpgradeable, ERC1155Upgradeable, UUPSUpgradeable, ISkypierVPN {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = Roles.OPERATOR_ROLE;
    bytes32 public constant VALIDATOR_ROLE = Roles.VALIDATOR_ROLE;
    bytes32 public constant BUILDER_ROLE = Roles.BUILDER_ROLE;
    bytes32 public constant EMPLOYEE_ROLE = Roles.EMPLOYEE_BADGE;

    SkypierBadges public badges;
    SkypierToken public skypierToken;
    OperatorToken public operatorToken;
    ValidatorToken public validatorToken;
    IClientToken public clientToken;
    address public paymentPool;
    address public builderToken;
    address public employeeBadge;
    uint256 public builderTokenId;
    uint256 public employeeBadgeId;
    ERC6551Registry public erc6551Registry;
    TokenBoundAccount public tokenBoundAccountImplementation;

    uint256 public stakeAmount;
    uint256 public validatorCount;

    mapping(address => Node) public nodes;
    mapping(address => bool) public revokedOperators;
    mapping(address => string) public operatorPeerIds;
    mapping(address => bool) public operatorApplications;
    mapping(address => uint256) public operatorTokenIds;
    mapping(address => bool) public operatorBadgeClaimed;
    mapping(address => address) public operatorTokenBoundAccounts;
    mapping(address => ValidatorInfo) private _validatorInfo;
    mapping(address => bool) public validatorBadgeClaimed;
    mapping(bytes32 => NodeConfig) private _nodeConfigs;
    mapping(address => bool) public betaTesters;
    address[] public operatorWaitlist;
    address[] private _validatedOperators;
    address[] private _validators;

    modifier onlyBuilderOrEmployee() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                hasRole(BUILDER_ROLE, msg.sender) ||
                hasRole(EMPLOYEE_ROLE, msg.sender) ||
                _holdsConfiguredBadge(msg.sender, builderToken, builderTokenId) ||
                _holdsConfiguredBadge(msg.sender, employeeBadge, employeeBadgeId),
            "Not authorized"
        );
        _;
    }

    modifier onlyValidator() {
        require(hasRole(VALIDATOR_ROLE, msg.sender) || isValidator(msg.sender), "Not authorized");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _badges, address _skypierToken, address _paymentPool, uint256 _stakeAmount)
        public
        initializer
    {
        __ERC1155_init("https://skypier.io/nft/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        badges = SkypierBadges(_badges);
        skypierToken = SkypierToken(_skypierToken);
        paymentPool = _paymentPool;
        stakeAmount = _stakeAmount;
        builderTokenId = 0;
        employeeBadgeId = 0;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function applyAsOperator(string calldata peerId) external override {
        require(!revokedOperators[msg.sender], "Operator is revoked");
        require(!nodes[msg.sender].isActive, "Already an operator");
        require(!operatorApplications[msg.sender], "Already applied");
        require(bytes(peerId).length > 0, "Peer ID required");
        operatorPeerIds[msg.sender] = peerId;
        operatorApplications[msg.sender] = true;
        operatorWaitlist.push(msg.sender);
        emit OperatorAdded(msg.sender, peerId);
    }

    function validateOperator(address operator, string calldata peerId) external override onlyValidator {
        require(operatorApplications[operator], "Operator not on waitlist");
        require(!revokedOperators[operator], "Operator is revoked");
        require(bytes(peerId).length > 0, "Peer ID required");
        operatorApplications[operator] = false;
        operatorPeerIds[operator] = peerId;
        nodes[operator] = Node(operator, peerId, true, block.timestamp, block.timestamp);
        _nodeConfigs[keccak256(bytes(peerId))] = NodeConfig(peerId, operator, block.timestamp, block.timestamp, true, 0, 0);
        _validatedOperators.push(operator);
        if (paymentPool != address(0)) IPaymentPool(paymentPool).registerOperator(payable(operator));
        emit OperatorValidated(msg.sender, operator, peerId);
    }

    function autoValidateOperator(address operator) external override onlyValidator {
        require(operatorApplications[operator], "Operator not on waitlist");
        _validateOperator(operator, operatorPeerIds[operator]);
    }

    function _validateOperator(address operator, string memory peerId) internal {
        require(!revokedOperators[operator], "Operator is revoked");
        require(bytes(peerId).length > 0, "Peer ID required");
        operatorApplications[operator] = false;
        operatorPeerIds[operator] = peerId;
        nodes[operator] = Node(operator, peerId, true, block.timestamp, block.timestamp);
        _nodeConfigs[keccak256(bytes(peerId))] = NodeConfig(peerId, operator, block.timestamp, block.timestamp, true, 0, 0);
        _validatedOperators.push(operator);
        if (paymentPool != address(0)) IPaymentPool(paymentPool).registerOperator(payable(operator));
        emit OperatorValidated(msg.sender, operator, peerId);
    }

    function applyAsValidator() external payable override {
        require(address(clientToken) != address(0), "Client token not configured");
        require(clientToken.isValidHolder(msg.sender, clientToken.CLIENT_BADGE()), "Client access required");
        require(!_validatorInfo[msg.sender].isActive, "Already a validator");
        require(msg.value >= stakeAmount, "Insufficient stake");
        _validatorInfo[msg.sender] = ValidatorInfo(msg.value, block.timestamp, 0, false, false);
        _validators.push(msg.sender);
        emit ValidatorApplied(msg.sender, msg.value);
    }

    function approveValidator(address validator, uint256 stakingAmount_) external override onlyBuilderOrEmployee {
        ValidatorInfo storage info = _validatorInfo[validator];
        require(info.appliedAt != 0, "Validator not applied");
        require(!info.isActive, "Validator already active");
        if (stakingAmount_ > 0) info.stakingAmount = stakingAmount_;
        info.approvedAt = block.timestamp;
        info.isApproved = true;
        info.isActive = true;
        validatorCount++;
        emit ValidatorApproved(validator, info.stakingAmount);
        if (paymentPool != address(0)) IPaymentPool(paymentPool).registerValidator(payable(validator));
    }

    function claimValidatorNFTBadge() external override {
        ValidatorInfo storage info = _validatorInfo[msg.sender];
        require(info.isApproved && info.isActive, "Validator not approved");
        require(address(validatorToken) != address(0), "Validator token not configured");
        require(!validatorBadgeClaimed[msg.sender], "Badge already claimed");
        validatorToken.mintValidatorBadge(msg.sender, info.stakingAmount);
        validatorBadgeClaimed[msg.sender] = true;
        emit ValidatorBadgeClaimed(msg.sender);
    }

    function claimOperatorNFTBadge() external override returns (uint256 tokenId, address account) {
        require(isValidatedOperator(msg.sender), "Operator not validated");
        require(address(operatorToken) != address(0), "Operator token not configured");
        require(!operatorBadgeClaimed[msg.sender], "Badge already claimed");
        tokenId = operatorToken.mint(msg.sender, operatorPeerIds[msg.sender]);
        operatorTokenIds[msg.sender] = tokenId;
        operatorBadgeClaimed[msg.sender] = true;
        if (address(erc6551Registry) != address(0) && address(tokenBoundAccountImplementation) != address(0)) {
            account = erc6551Registry.account(address(tokenBoundAccountImplementation), block.chainid, address(operatorToken), tokenId, uint256(uint160(msg.sender)));
            erc6551Registry.createAccount(address(tokenBoundAccountImplementation), block.chainid, address(operatorToken), tokenId, uint256(uint160(msg.sender)));
            operatorTokenBoundAccounts[msg.sender] = account;
        }
        emit OperatorBadgeClaimed(msg.sender, tokenId, account);
    }

    function registerNode(string calldata peerId) external override {
        require(isValidatedOperator(msg.sender), "Operator not validated");
        require(keccak256(bytes(operatorPeerIds[msg.sender])) == keccak256(bytes(peerId)), "Peer ID mismatch");
        nodes[msg.sender].lastHeartbeat = block.timestamp;
        nodes[msg.sender].isActive = true;
        _nodeConfigs[keccak256(bytes(peerId))].lastActive = block.timestamp;
        _nodeConfigs[keccak256(bytes(peerId))].isActive = true;
        emit NodeStatusChanged(msg.sender, true);
    }

    function deregisterNode(string calldata peerId) external override {
        require(keccak256(bytes(nodes[msg.sender].peerId)) == keccak256(bytes(peerId)), "Peer ID mismatch");
        require(nodes[msg.sender].isActive, "Node not active");
        nodes[msg.sender].isActive = false;
        _nodeConfigs[keccak256(bytes(peerId))].isActive = false;
        emit NodeStatusChanged(msg.sender, false);
    }

    function updateHeartbeat() external {
        require(isValidatedOperator(msg.sender), "Operator not validated");
        nodes[msg.sender].lastHeartbeat = block.timestamp;
        _nodeConfigs[keccak256(bytes(nodes[msg.sender].peerId))].lastActive = block.timestamp;
    }

    function setNodeActiveStatus(string calldata peerId, bool isActive) external override onlyBuilderOrEmployee {
        for (uint256 i = 0; i < _validatedOperators.length; i++) {
            address operator = _validatedOperators[i];
            if (keccak256(bytes(nodes[operator].peerId)) == keccak256(bytes(peerId))) {
                nodes[operator].isActive = isActive;
                _nodeConfigs[keccak256(bytes(peerId))].isActive = isActive;
                emit NodeStatusChanged(operator, isActive);
                return;
            }
        }
        revert("Node not found");
    }

    function revokeOperator(address operator) external override onlyBuilderOrEmployee {
        require(nodes[operator].isActive, "Operator not active");
        revokedOperators[operator] = true;
        nodes[operator].isActive = false;
        _nodeConfigs[keccak256(bytes(nodes[operator].peerId))].isActive = false;
        if (operatorBadgeClaimed[operator] && address(operatorToken) != address(0)) operatorToken.deregisterOperator(operatorTokenIds[operator]);
        if (paymentPool != address(0)) IPaymentPool(paymentPool).deactivateParticipant(operator, "operator");
        emit OperatorRemoved(operator);
    }

    function removeValidator(address validator) external override onlyBuilderOrEmployee {
        ValidatorInfo storage info = _validatorInfo[validator];
        require(info.isActive, "Validator not active");
        info.isActive = false;
        if (validatorCount > 0) validatorCount--;
        if (validatorBadgeClaimed[validator] && address(validatorToken) != address(0)) validatorToken.revokeValidatorBadge(validator);
        if (paymentPool != address(0)) IPaymentPool(paymentPool).deactivateParticipant(validator, "validator");
        emit ValidatorRemoved(validator);
    }

    function assignBetaTesterBadge(address recipient) external override onlyBuilderOrEmployee {
        require(address(badges) != address(0), "Badges not configured");
        badges.mintBadge(recipient, Roles.BETA_TESTER_BADGE_ID, 1, "");
        betaTesters[recipient] = true;
        emit BetaTesterAssigned(recipient);
    }

    function revokeBetaTesterBadge(address recipient) external override onlyBuilderOrEmployee {
        require(address(badges) != address(0), "Badges not configured");
        badges.revokeBadge(recipient, Roles.BETA_TESTER_BADGE_ID);
        betaTesters[recipient] = false;
        emit BetaTesterRevoked(recipient);
    }

    function reportNodeMetrics(string calldata peerId, uint256 dataVolume, uint256 duration) external override {
        require(isValidatedOperator(msg.sender), "Operator not validated");
        require(keccak256(bytes(nodes[msg.sender].peerId)) == keccak256(bytes(peerId)), "Peer ID mismatch");
        nodes[msg.sender].lastHeartbeat = block.timestamp;
        NodeConfig storage config = _nodeConfigs[keccak256(bytes(peerId))];
        config.lastActive = block.timestamp;
        config.dataVolume += dataVolume;
        config.uptime += duration;
        require(paymentPool != address(0), "Payment pool not configured");
        IPaymentPool(paymentPool).recordOperatorMetrics(msg.sender, dataVolume, duration);
        emit NodeMetricsReported(msg.sender, dataVolume, duration);
    }

    function getNode(address operator) external view override returns (Node memory) { return nodes[operator]; }

    function getNodeConfig(string calldata peerId) external view override returns (NodeConfig memory) {
        return _nodeConfigs[keccak256(bytes(peerId))];
    }

    function getOperatorPeerId(address operator) external view override returns (string memory) {
        return operatorPeerIds[operator];
    }

    function getOperatorTokenBoundAccount(address operator) external view override returns (address) {
        return operatorTokenBoundAccounts[operator];
    }

    function getOperatorInfo(address operator) external view override returns (OperatorInfo memory) {
        return OperatorInfo(operatorTokenIds[operator], operatorPeerIds[operator], nodes[operator].registeredAt, isValidatedOperator(operator));
    }

    function getValidatorInfo(address validator) external view override returns (ValidatorInfo memory) { return _validatorInfo[validator]; }

    function isValidatedOperator(address operator) public view override returns (bool) {
        return nodes[operator].isActive && !revokedOperators[operator];
    }

    function isValidator(address validator) public view override returns (bool) {
        return _validatorInfo[validator].isActive || (address(validatorToken) != address(0) && validatorToken.balanceOf(validator, validatorToken.VALIDATOR_BADGE()) > 0);
    }

    function hasBetaTesterBadge(address account) public view override returns (bool) {
        return betaTesters[account] || (address(badges) != address(0) && badges.balanceOf(account, Roles.BETA_TESTER_BADGE_ID) > 0);
    }

    function getValidatedOperatorCount() external view override returns (uint256) {
        uint256 count;
        for (uint256 i = 0; i < _validatedOperators.length; i++) if (isValidatedOperator(_validatedOperators[i])) count++;
        return count;
    }

    function getValidatorCount() external view override returns (uint256) { return validatorCount; }

    function getValidatedOperators(uint256 startIndex, uint256 endIndex) external view override returns (address[] memory result) {
        require(startIndex <= endIndex && endIndex <= _validatedOperators.length, "Invalid range");
        result = new address[](endIndex - startIndex);
        uint256 cursor;
        for (uint256 i = startIndex; i < endIndex; i++) if (isValidatedOperator(_validatedOperators[i])) result[cursor++] = _validatedOperators[i];
        assembly { mstore(result, cursor) }
    }

    function getValidators(uint256 startIndex, uint256 endIndex) external view override returns (address[] memory result) {
        require(startIndex <= endIndex && endIndex <= _validators.length, "Invalid range");
        result = new address[](endIndex - startIndex);
        uint256 cursor;
        for (uint256 i = startIndex; i < endIndex; i++) if (isValidator(_validators[i])) result[cursor++] = _validators[i];
        assembly { mstore(result, cursor) }
    }

    function setPaymentPool(address newPaymentPool) external override onlyRole(DEFAULT_ADMIN_ROLE) { paymentPool = newPaymentPool; emit DependencyUpdated("PAYMENT_POOL", newPaymentPool); }
    function setOperatorToken(address newOperatorToken) external override onlyRole(DEFAULT_ADMIN_ROLE) { operatorToken = OperatorToken(newOperatorToken); emit DependencyUpdated("OPERATOR_TOKEN", newOperatorToken); }
    function setValidatorToken(address newValidatorToken) external override onlyRole(DEFAULT_ADMIN) { validatorToken = ValidatorToken(newValidatorToken); emit DependencyUpdated("VALIDATOR_TOKEN", newValidatorToken); }
    function setClientToken(address newClientToken) external override onlyRole(DEFAULT_ADMIN_ROLE) { clientToken = IClientToken(newClientToken); emit DependencyUpdated("CLIENT_TOKEN", newClientToken); }
    function setSkypierBadges(address newSkypierBadges) external override onlyRole(DEFAULT_ADMIN_ROLE) { badges = SkypierBadges(newSkypierBadges); emit DependencyUpdated("SKYPIER_BADGES", newSkypierBadges); }
    function setBuilderToken(address newBuilderToken) external override onlyRole(DEFAULT_ADMIN_ROLE) { builderToken = newBuilderToken; emit DependencyUpdated("BUILDER_TOKEN", newBuilderToken); }
    function setEmployeeBadge(address newEmployeeBadge) external override onlyRole(DEFAULT_ADMIN_ROLE) { employeeBadge = newEmployeeBadge; emit DependencyUpdated("EMPLOYEE_BADGE", newEmployeeBadge); }
    function setBuilderTokenId(uint256 newBuilderTokenId) external override onlyRole(DEFAULT_ADMIN_ROLE) { builderTokenId = newBuilderTokenId; }
    function setEmployeeBadgeId(uint256 newEmployeeBadgeId) external override onlyRole(DEFAULT_ADMIN_ROLE) { employeeBadgeId = newEmployeeBadgeId; }

    function setERC6551Dependencies(address registry, address implementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        erc6551Registry = ERC6551Registry(registry);
        tokenBoundAccountImplementation = TokenBoundAccount(implementation);
    }

    function _holdsConfiguredBadge(address account, address token, uint256 tokenId) internal view returns (bool) {
        return token != address(0) && IERC1155(token).balanceOf(account, tokenId) > 0;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) { return super.supportsInterface(interfaceId); }
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
