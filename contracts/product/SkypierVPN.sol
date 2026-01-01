// contracts/product/SkypierVPN.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/ITokenBoundAccount.sol";
import "./tokens/SkypierBadges.sol";
import "./tokens/SkypierToken.sol";
import "../lib/Roles.sol";

/**
 * Defines the implementation of the core functionality for node management, operator/validator onboarding,
 * and interactions with the payment system and token badges.
 */
contract SkypierVPN is UUPSUpgradeable, AccessControlUpgradeable, Initializable, ERC1155Upgradeable, ERC165 {
    using SafeMath for uint256;

    // Roles
    bytes32 public constant ADMIN = Roles.ADMIN_ROLE;
    bytes32 public constant OPERATOR = Roles.OPERATOR_ROLE;
    bytes32 public constant VALIDATOR = Roles.VALIDATOR_ROLE;
    bytes32 public constant BUILDER_ROLE = Roles.BUILDER_ROLE;
    bytes32 public constant EMPLOYEE_BADGE = Roles.EMPLOYEE_BADGE;
    // bytes32 public constant NODE_ADMIN = keccak256("NODE_ADMIN");

    // Contracts
    SkypierBadges public badges;  // contains ISkypierBadge
    address public paymentPool;
    SkypierToken public skypierToken; // contains ISkypierToken

    // Node management
    struct Node {
        address owner;
        string peerId;
        address tokenBoundAccount;
        bool isActive;
        uint256 registeredAt;
        uint256 lastHeartbeat;
    }

    mapping(address => Node) public nodes;
    mapping(address => bool) public revokedOperators;
    address[] public operatorWaitlist;    // mapping(address => string) public operatorsWaitingList;
    mapping(address => uint256) public operatorCount;

    // Summary Count Variables from old contracts
    uint256 public stakeAmount;
    uint256 public validatorCount;
    uint256 public validatedOperatorsCount;
    uint256 public denyListCount;

    mapping(address => string) public validatedOperators;
    mapping(address => string) public revokesOperators;

    // Events
    event NodeRegistered(address indexed owner, string peerId, address tokenBoundAccount);
    event NodeRevoked(address indexed owner, string peerId);
    event OperatorAddedToWaitlist(address indexed operator);
    event OperatorValidated(address indexed operator, string peerId);
    event OperatorNFTClaimed(address indexed operator, uint256 tokenId);
    // Events from old contracts  
    event NewOperatorApplication(address indexed operator, string peerId);
    event NewOperatorValidated(
        address indexed operator,
        string peerId,
        address validator
    );
    event NewOperatorRevoked(address indexed operator, string peerId);

    // event NodeDenied(address indexed operator, string peerId);

    constructor(address _badges, address _paymentPool) {
        badges = SkypierBadges(_badges);
        paymentPool = _paymentPool;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BUILDER_ROLE, msg.sender);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _stakeAmount, uint256 _validatorCount, address _skypierTokenAddress,
        address _skypierBadgeAddress
    ) public initializer {
        // __Ownable_init(msg.sender);
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        stakeAmount = _stakeAmount;
        validatorCount = _validatorCount;
        skypierToken = SkypierToken(_skypierTokenAddress);
        skypierBadge = SkypierBadge(_skypierBadgeAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Apply to become an operator
     */
    function applyAsOperator() external {
        require(!revokedOperators[msg.sender], "Operator is revoked");
        require(!nodes[msg.sender].isActive, "Already an operator");

        operatorWaitlist.push(msg.sender);
        emit OperatorAddedToWaitlist(msg.sender);
    }

    /**
     * @dev Validate an operator (called by validators or builders with EMPLOYEE badge)
     * @param _operator Address of the operator to validate
     * @param _peerId PeerID of the operator's node
     */
    function validateOperator(address _operator, string memory _peerId) external {
        require(hasRole(EMPLOYEE_BADGE, msg.sender) || hasRole(BUILDER_ROLE, msg.sender), "Not authorized");

        bool isOnWaitlist = false;
        for (uint256 i = 0; i < operatorWaitlist.length; i++) {
            if (operatorWaitlist[i] == _operator) {
                isOnWaitlist = true;
                // Remove from waitlist
                operatorWaitlist[i] = operatorWaitlist[operatorWaitlist.length - 1];
                operatorWaitlist.pop();
                break;
            }
        }

        require(isOnWaitlist, "Operator not on waitlist");

        // Register the node
        nodes[_operator] = Node({
            owner: _operator,
            peerId: _peerId,
            tokenBoundAccount: address(0),
            isActive: true,
            registeredAt: block.timestamp,
            lastHeartbeat: block.timestamp
        });

        emit OperatorValidated(_operator, _peerId);
    }

    /**
     * @dev Claim operator NFT badge after validation
     */
    function claimOperatorNFTBadge() external {
        require(nodes[msg.sender].isActive, "Not a validated operator");
        require(nodes[msg.sender].tokenBoundAccount == address(0), "Already claimed badge");

        // Mint operator badge through SkypierBadges contract
        address badgeOwner = msg.sender;
        string memory peerId = nodes[badgeOwner].peerId;

        // In a real implementation, this would be called by the SkypierBadges contract
        // For this example, we'll simulate it
        uint256 tokenId = operatorCount[badgeOwner] + 1;
        operatorCount[badgeOwner] = tokenId;

        // Get the TokenBoundAccount for this badge
        address account = badges.getTokenBoundAccount(tokenId);
        nodes[badgeOwner].tokenBoundAccount = account;

        emit OperatorNFTClaimed(badgeOwner, tokenId);
    }

    /**
     * @dev Update node heartbeat
     */
    function updateHeartbeat() external {
        require(nodes[msg.sender].isActive, "Not a validated operator");

        nodes[msg.sender].lastHeartbeat = block.timestamp;
    }

    /**
     * @dev Revoke an operator (called by builders with EMPLOYEE_BADGE badge)
     * @param _operator Address of the operator to revoke
     */
    function revokeOperator(address _operator) external {
        require(hasRole(EMPLOYEE_BADGE, msg.sender) || hasRole(BUILDER_ROLE, msg.sender), "Not authorized");
        require(nodes[_operator].isActive, "Operator not active");

        revokedOperators[_operator] = true;
        nodes[_operator].isActive = false;

        emit NodeRevoked(_operator, nodes[_operator].peerId);
    }

    /**
     * @dev Check if an address is a validated operator
     * @param _operator Address to check
     * @return bool True if the address is a validated operator
     */
    function isValidatedOperator(address _operator) external view returns (bool) {
        return nodes[_operator].isActive && !revokedOperators[_operator];
    }

    /**
     * @dev Get operator's TokenBoundAccount
     * @param _operator Address of the operator
     * @return address TokenBoundAccount address
     */
    function getOperatorTokenBoundAccount(address _operator) external view returns (address) {
        return nodes[_operator].tokenBoundAccount;
    }

    /**
     * @dev Get operator's PeerID
     * @param _operator Address of the operator
     * @return string PeerID
     */
    function getOperatorPeerId(address _operator) external view returns (string memory) {
        return nodes[_operator].peerId;
    }

    /**
     * @dev Override supportsInterface to include custom interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ITokenBoundAccount).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // Logic Starts
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyValidator() {
        require(
            hasRole(VALIDATOR_ROLE, msg.sender),
            "Caller is not a validator"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, msg.sender),
            "Caller is not an operator"
        );
        _;
    }

    function applyAsOperator(string memory peerId) external payable {
        require(msg.value == stakeAmount, "Incorrect stake amount");
        require(
            bytes(revokesOperators[msg.sender]).length == 0,
            "Operator is denied"
        );

        operatorsWaitingList[msg.sender] = peerId;
        emit NewOperatorApplication(msg.sender, peerId);
    }

    function validateOperator(address operator) external onlyValidator {
        require(
            bytes(operatorsWaitingList[operator]).length != 0,
            "Operator is not in waiting list"
        );

        validatedOperators[operator] = operatorsWaitingList[operator];
        delete operatorsWaitingList[operator];
        validatedOperatorsCount++;

        emit NewOperatorValidated(
            operator,
            validatedOperators[operator],
            msg.sender
        );
    }

    function revokeOperator(address operator) external onlyAdmin {
        require(
            bytes(validatedOperators[operator]).length != 0,
            "Operator is not validated"
        );

        revokesOperators[operator] = validatedOperators[operator];
        delete validatedOperators[operator];
        validatedOperatorsCount--;
        denyListCount++;

        emit NewOperatorRevoked(operator, revokesOperators[operator]);
    }

    function updateStakeAmount(uint256 newStakeAmount) external onlyAdmin {
        stakeAmount = newStakeAmount;
    }

    // Public view functions
    function getValidatedOperatorCount() external view returns (uint256) {
        return validatedOperatorsCount;
    }

    function getValidatorCount() external view returns (uint256) {
        return validatorCount;
    }

    function getDenyListCount() external view returns (uint256) {
        return denyListCount;
    }
}