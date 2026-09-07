// contracts/product/tokens/SkypierBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../../interfaces/IBadges.sol";

/**
 * @title SkypierBadges
 * @dev ERC1155-based badges for Skypier roles and achievements
 */
contract SkypierBadges is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, IBadges {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 private _nextTokenId;
    
    // Mapping to track badge attributes: badgeId => holder => BadgeAttributes
    mapping(uint256 => mapping(address => BadgeAttributes)) private _badgeAttributes;

    event BadgeMinted(address indexed to, uint256 indexed tokenId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/badges/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Mint a badge
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient");
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId, amount, "");
        emit BadgeMinted(to, tokenId, amount);
    }

    /**
     * @dev Mint a specific token ID
     */
    function mintToken(address to, uint256 tokenId, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient");
        _mint(to, tokenId, amount, "");
        emit BadgeMinted(to, tokenId, amount);
    }

    /**
     * @dev Mint a badge with attributes (IBadges interface implementation)
     */
    function mintBadge(
        address to,
        uint256 badgeId,
        uint256 amount,
        bytes memory data
    ) external override onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient");
        _mint(to, badgeId, amount, data);
        _badgeAttributes[badgeId][to] = BadgeAttributes(
            to,
            msg.sender,
            block.timestamp,
            0  // expiresAt = 0 means no expiry
        );
        emit BadgeMinted(to, badgeId, amount);
    }

    /**
     * @dev Revoke a badge (IBadges interface implementation)
     */
    function revokeBadge(address from, uint256 badgeId) external override onlyRole(MINTER_ROLE) {
        require(from != address(0), "Invalid address");
        uint256 balance = balanceOf(from, badgeId);
        if (balance > 0) {
            _burn(from, badgeId, balance);
        }
        delete _badgeAttributes[badgeId][from];
    }

    /**
     * @dev Get badge attributes (IBadges interface implementation)
     */
    function getBadgeAttributes(uint256 badgeId, address holder)
        external
        view
        override
        returns (BadgeAttributes memory)
    {
        return _badgeAttributes[badgeId][holder];
    }

    /**
     * @dev Support AccessControl and IBadges interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IBadges).interfaceId || super.supportsInterface(interfaceId);
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