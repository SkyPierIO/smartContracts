// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IBadges.sol";
import "./IPaymentPool.sol";

/**
 * @dev Interface for the Skypier VPN contract.
 * Defines the core functionality for node management, operator/validator onboarding,
 * and interactions with the payment system and token badges.
 */
interface ISkypierVPN is IAccessControl {
    // ========== Events ==========
    /// @notice Emitted when a new operator is added
    event OperatorAdded(address indexed operator, uint256 indexed tokenId, string peerId);

    /// @notice Emitted when an operator is removed
    event OperatorRemoved(address indexed operator, uint256 indexed tokenId);

    /// @notice Emitted when a new validator is added
    event ValidatorAdded(address indexed validator, uint256 indexed tokenId);

    /// @notice Emitted when a validator is removed
    event ValidatorRemoved(address indexed validator, uint256 indexed tokenId);

    /// @notice Emitted when a node is registered
    event NodeRegistered(address indexed operator, string peerId, uint256 timestamp);

    /// @notice Emitted when a node is deregistered
    event NodeDeregistered(address indexed operator, string peerId, uint256 timestamp);

    /// @notice Emitted when an operator is validated
    event OperatorValidated(address indexed validator, address indexed operator, uint256 timestamp);

    /// @notice Emitted when a beta tester badge is assigned
    event BetaTesterAssigned(address indexed recipient, uint256 indexed tokenId);

    /// @notice Emitted when a beta tester badge is revoked
    event BetaTesterRevoked(address indexed recipient, uint256 indexed tokenId);

    // ========== Structs ==========
    struct NodeConfig {
        string peerId;
        address operator;
        uint256 registeredAt;
        uint256 lastActive;
        bool isActive;
        uint256 dataVolume;
        uint256 uptime;
    }

    struct OperatorInfo {
        uint256 tokenId;
        string peerId;
        uint256 validationCount;
        uint256 activeSince;
        bool isValidated;
    }

    struct ValidatorInfo {
        uint256 tokenId;
        address addedBy;
        uint256 activeSince;
    }

    // ========== Core Functions ==========
    /// @notice Apply to become an operator
    /// @dev Adds the caller to the operator waitlist
    function applyAsOperator(string calldata peerId) external;

    /// @notice Apply to become a validator
    /// @dev Requires ClientToken ownership
    function applyAsValidator() external;

    /// @notice Validate an operator (called by validators)
    /// @param operator Address of the operator to validate
    function validateOperator(address operator) external;

    /// @notice Auto-validate an operator if conditions are met
    /// @param operator Address of the operator to auto-validate
    function autoValidateOperator(address operator) external;

    /// @notice Claim operator NFT badge after validation
    function claimOperatorNFTBadge() external;

    /// @notice Claim validator NFT badge after approval
    function claimValidatorNFTBadge() external;

    /// @notice Register a new node
    /// @param peerId The peer ID of the node
    function registerNode(string calldata peerId) external;

    /// @notice Deregister a node
    /// @param peerId The peer ID of the node to deregister
    function deregisterNode(string calldata peerId) external;

    /// @notice Revoke an operator (called by builders with QA badge)
    /// @param operator Address of the operator to revoke
    function revokeOperator(address operator) external;

    /// @notice Remove a validator (called by builders with QA badge)
    /// @param validator Address of the validator to remove
    function removeValidator(address validator) external;

    /// @notice Assign beta tester badge (called by builders with QA badge)
    /// @param recipient Address to receive the badge
    function assignBetaTesterBadge(address recipient) external;

    /// @notice Revoke beta tester badge (called by builders with QA badge)
    /// @param recipient Address to revoke the badge from
    function revokeBetaTesterBadge(address recipient) external;

    /// @notice Toggle node active status
    /// @param peerId The peer ID of the node
    /// @param isActive Whether the node should be active
    function setNodeActiveStatus(string calldata peerId, bool isActive) external;

    // ========== View Functions ==========
    /// @notice Get operator information
    /// @param operator Address of the operator
    function getOperatorInfo(address operator) external view returns (OperatorInfo memory);

    /// @notice Get validator information
    /// @param validator Address of the validator
    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory);

    /// @notice Get node configuration
    /// @param peerId The peer ID of the node
    function getNodeConfig(string calldata peerId) external view returns (NodeConfig memory);

    /// @notice Check if an address is a validated operator
    /// @param operator Address to check
    function isValidatedOperator(address operator) external view returns (bool);

    /// @notice Check if an address is a validator
    /// @param validator Address to check
    function isValidator(address validator) external view returns (bool);

    /// @notice Check if an address has a beta tester badge
    /// @param account Address to check
    function hasBetaTesterBadge(address account) external view returns (bool);

    /// @notice Get the number of validated operators
    function getValidatedOperatorCount() external view returns (uint256);

    /// @notice Get the number of validators
    function getValidatorCount() external view returns (uint256);

    /// @notice Get the list of validated operators
    function getValidatedOperators(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory);

    /// @notice Get the list of validators
    function getValidators(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory);

    // ========== Token and Payment Interactions ==========
    /// @notice Get the OperatorToken contract address
    function operatorToken() external view returns (IERC1155);

    /// @notice Get the ValidatorToken contract address
    function validatorToken() external view returns (IERC1155);

    /// @notice Get the ClientToken contract address
    function clientToken() external view returns (IERC1155);

    /// @notice Get the PaymentPool contract address
    function paymentPool() external view returns (IPaymentPool);

    /// @notice Get the SkypierBadges contract address
    function skypierBadges() external view returns (IBadges);

    /// @notice Update the payment pool address
    /// @dev Can only be called by BUILDER_ROLE
    /// @param newPaymentPool Address of the new payment pool
    function setPaymentPool(address newPaymentPool) external;

    /// @notice Update the operator token address
    /// @dev Can only be called by BUILDER_ROLE
    /// @param newOperatorToken Address of the new operator token contract
    function setOperatorToken(address newOperatorToken) external;

    /// @notice Update the validator token address
    /// @dev Can only be called by BUILDER_ROLE
    /// @param newValidatorToken Address of the new validator token contract
    function setValidatorToken(address newValidatorToken) external;

    /// @notice Update the client token address
    /// @dev Can only be called by BUILDER_ROLE
    /// @param newClientToken Address of the new client token contract
    function setClientToken(address newClientToken) external;

    /// @notice Update the SkypierBadges address
    /// @dev Can only be called by BUILDER_ROLE
    /// @param newSkypierBadges Address of the new SkypierBadges contract
    function setSkypierBadges(address newSkypierBadges) external;

    /// @notice Report node metrics for payment calculation
    /// @dev Should be called by operators for their nodes
    /// @param peerId The peer ID of the node
    /// @param dataVolume Data volume handled by the node
    /// @param duration Duration the node was active
    function reportNodeMetrics(string calldata peerId, uint256 dataVolume, uint256 duration) external;
}