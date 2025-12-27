// contracts/product/SkypierVPN.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/ITokenBoundAccount.sol";
import "./tokens/SkypierBadges.sol";

contract SkypierVPN is AccessControl, ERC165 {
    using SafeMath for uint256;

    // Roles
    bytes32 public constant BUILDER_ROLE = keccak256("BUILDER_ROLE");
    bytes32 public constant QA_BADGE = keccak256("QA_BADGE");

    // Contracts
    SkypierBadges public badges;
    address public paymentPool;

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
    address[] public operatorWaitlist;
    mapping(address => uint256) public operatorCount;

    // Events
    event NodeRegistered(address indexed owner, string peerId, address tokenBoundAccount);
    event NodeRevoked(address indexed owner, string peerId);
    event OperatorAddedToWaitlist(address indexed operator);
    event OperatorValidated(address indexed operator, string peerId);
    event OperatorNFTClaimed(address indexed operator, uint256 tokenId);

    constructor(address _badges, address _paymentPool) {
        badges = SkypierBadges(_badges);
        paymentPool = _paymentPool;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BUILDER_ROLE, msg.sender);
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
     * @dev Validate an operator (called by validators or builders with QA badge)
     * @param _operator Address of the operator to validate
     * @param _peerId PeerID of the operator's node
     */
    function validateOperator(address _operator, string memory _peerId) external {
        require(hasRole(QA_BADGE, msg.sender) || hasRole(BUILDER_ROLE, msg.sender), "Not authorized");

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
     * @dev Revoke an operator (called by builders with QA badge)
     * @param _operator Address of the operator to revoke
     */
    function revokeOperator(address _operator) external {
        require(hasRole(QA_BADGE, msg.sender) || hasRole(BUILDER_ROLE, msg.sender), "Not authorized");
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
}