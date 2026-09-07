// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @dev Orchestration interface for the Skypier persona and node journeys.
 */
interface ISkypierVPN is IAccessControl {
    struct Node {
        address owner;
        string peerId;
        bool isActive;
        uint256 registeredAt;
        uint256 lastHeartbeat;
    }

    struct OperatorInfo {
        uint256 tokenId;
        string peerId;
        uint256 activeSince;
        bool isValidated;
    }

    struct ValidatorInfo {
        uint256 stakingAmount;
        uint256 appliedAt;
        uint256 approvedAt;
        bool isApproved;
        bool isActive;
    }

    struct NodeConfig {
        string peerId;
        address operator;
        uint256 registeredAt;
        uint256 lastActive;
        bool isActive;
        uint256 dataVolume;
        uint256 uptime;
    }

    event OperatorAdded(address indexed operator, string peerId);
    event OperatorValidated(address indexed validator, address indexed operator, string peerId);
    event OperatorRemoved(address indexed operator);
    event ValidatorApplied(address indexed validator, uint256 stakingAmount);
    event ValidatorApproved(address indexed validator, uint256 stakingAmount);
    event ValidatorRemoved(address indexed validator);
    event ValidatorRemovalRecorded(address indexed validator, bool forCause, uint256 removalCount);
    event OperatorBadgeClaimed(address indexed operator, uint256 indexed tokenId, address account);
    event ValidatorBadgeClaimed(address indexed validator);
    event BetaTesterAssigned(address indexed recipient);
    event BetaTesterRevoked(address indexed recipient);
    event NodeStatusChanged(address indexed operator, bool isActive);
    event NodeMetricsReported(address indexed operator, uint256 dataVolume, uint256 duration);
    event DependencyUpdated(bytes32 indexed dependency, address indexed value);

    function applyAsOperator(string calldata peerId) external;
    function validateOperator(address operator, string calldata peerId) external;
    function revokeOperator(address operator) external;
    function applyAsValidator() external payable;
    function approveValidator(address validator, uint256 stakingAmount) external;
    function claimOperatorNFTBadge() external returns (uint256 tokenId, address account);
    function claimValidatorNFTBadge() external;
    function removeValidator(address validator) external;
    function removeValidatorForCause(address validator) external;
    function registerNode(string calldata peerId) external;
    function deregisterNode(string calldata peerId) external;
    function updateHeartbeat() external;
    function setNodeActiveStatus(string calldata peerId, bool isActive) external;
    function assignBetaTesterBadge(address recipient) external;
    function revokeBetaTesterBadge(address recipient) external;
    function reportNodeMetrics(string calldata peerId, uint256 dataVolume, uint256 duration) external;
    function autoValidateOperator(address operator) external;

    function getNode(address operator) external view returns (Node memory);
    function getNodeConfig(string calldata peerId) external view returns (NodeConfig memory);
    function getOperatorPeerId(address operator) external view returns (string memory);
    function getOperatorTokenBoundAccount(address operator) external view returns (address);
    function getOperatorInfo(address operator) external view returns (OperatorInfo memory);
    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory);
    function isValidatorReapplicationBlocked(address validator) external view returns (bool);
    function getValidatorRemovalHistory(address validator)
        external
        view
        returns (uint256 removalCount, bool lastRemovalWasForCause, uint256 lastRemovalAt);
    function isValidatedOperator(address operator) external view returns (bool);
    function isValidator(address validator) external view returns (bool);
    function hasBetaTesterBadge(address account) external view returns (bool);
    function getValidatedOperatorCount() external view returns (uint256);
    function getValidatorCount() external view returns (uint256);
    function getValidatedOperators(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory);
    function getValidators(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory);

    function setPaymentPool(address newPaymentPool) external;
    function setOperatorToken(address newOperatorToken) external;
    function setValidatorToken(address newValidatorToken) external;
    function setClientToken(address newClientToken) external;
    function setSkypierBadges(address newSkypierBadges) external;
    function setBuilderToken(address newBuilderToken) external;
    function setEmployeeBadge(address newEmployeeBadge) external;
    function setBuilderTokenId(uint256 newBuilderTokenId) external;
    function setEmployeeBadgeId(uint256 newEmployeeBadgeId) external;
    function setERC6551Dependencies(address registry, address implementation) external;
    function setValidatorEscrow(address newValidatorEscrow) external;
    function releaseValidatorStake(address validator) external;
    function slashValidatorStake(address validator, address payable recipient, uint256 amount) external;
}