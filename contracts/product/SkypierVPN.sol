// contracts/product/SkypierVPN.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./tokens/SkypierBadges.sol";
import "./tokens/SkypierToken.sol";

/**
 * @title SkypierVPN
 * @dev Core Skypier VPN contract for node and operator management
 */
contract SkypierVPN is Initializable, AccessControlUpgradeable, ERC1155Upgradeable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    struct Node {
        address owner;
        string peerId;
        bool isActive;
        uint256 registeredAt;
        uint256 lastHeartbeat;
    }

    // State
    SkypierBadges public badges;
    SkypierToken public skypierToken;
    address public paymentPool;

    uint256 public stakeAmount;
    uint256 public validatorCount;

    mapping(address => Node) public nodes;
    mapping(address => bool) public revokedOperators;
    mapping(address => string) public operatorPeerIds;
    address[] public operatorWaitlist;

    // Events
    event NodeRegistered(address indexed owner, string peerId);
    event NodeRevoked(address indexed owner);
    event OperatorAddedToWaitlist(address indexed operator);
    event OperatorValidated(address indexed operator, string peerId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _badges,
        address _skypierToken,
        address _paymentPool,
        uint256 _stakeAmount
    ) public initializer {
        __ERC1155_init("https://skypier.io/nft/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        badges = SkypierBadges(_badges);
        skypierToken = SkypierToken(_skypierToken);
        paymentPool = _paymentPool;
        stakeAmount = _stakeAmount;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Apply to become an operator
     */
    function applyAsOperator(string memory _peerId) external {
        require(!revokedOperators[msg.sender], "Operator is revoked");
        require(!nodes[msg.sender].isActive, "Already an operator");

        operatorPeerIds[msg.sender] = _peerId;
        operatorWaitlist.push(msg.sender);
        emit OperatorAddedToWaitlist(msg.sender);
    }

    /**
     * @dev Validate an operator (called by validators)
     */
    function validateOperator(address _operator, string memory _peerId) external onlyRole(VALIDATOR_ROLE) {
        require(bytes(operatorPeerIds[_operator]).length > 0, "Operator not on waitlist");

        // Register the node
        nodes[_operator] = Node({
            owner: _operator,
            peerId: _peerId,
            isActive: true,
            registeredAt: block.timestamp,
            lastHeartbeat: block.timestamp
        });

        emit OperatorValidated(_operator, _peerId);
    }

    /**
     * @dev Revoke an operator
     */
    function revokeOperator(address _operator) external onlyRole(ADMIN_ROLE) {
        require(nodes[_operator].isActive, "Operator not active");

        revokedOperators[_operator] = true;
        nodes[_operator].isActive = false;

        emit NodeRevoked(_operator);
    }

    /**
     * @dev Get operator info
     */
    function getNode(address _operator) external view returns (Node memory) {
        return nodes[_operator];
    }

    /**
     * @dev Check if address is validated operator
     */
    function isValidatedOperator(address _operator) external view returns (bool) {
        return nodes[_operator].isActive && !revokedOperators[_operator];
    }

    /**
     * @dev Support interface override
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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