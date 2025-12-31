// contracts/internal/tokens/EmployeeLevelBadge.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract EmployeeLevelBadge is ERC20, AccessControlUpgradeable, ReentrancyGuard{
    uint256 public constant WALLET_CAP = 6;
    uint256 public constant BADGE_EXPIRY = 78 weeks;

    struct BadgeHolder {
        uint256 expiry;     // Expiry timestamp
        uint256 mintTime;   // When the badge was minted
    }

    mapping(address => BadgeHolder) private _badgeHolders;
    mapping(address => uint256) private _lastClaim;

    IERC1155 public immutable builderToken;
    uint256 public immutable builderTokenId;
    mapping(uint256 => uint256) private _expiry;
    uint256 public expiryDuration = 1 years;

    event BadgeExpired(uint256 indexed tokenId, uint256 expiryTime);
    event ExpiryExtended(uint256 indexed tokenId, uint256 newExpiryTime);

    constructor(address _builderToken, uint256 _builderTokenId)
        ERC1155("https://skypier.io/employee/{id}.json")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        builderToken = IERC1155(_builderToken);
        builderTokenId = _builderTokenId;
    }

    modifier onlyBuilderTokenHolder() {
        require(
            builderToken.balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token"
        );
        _;
    }

    function isExpired(uint256 tokenId) public view returns (bool) {
        return _expiry[tokenId] != 0 && block.timestamp >= _expiry[tokenId];
    }

    function extendExpiry(uint256 tokenId, uint256 newExpiryDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(_expiry[tokenId] != 0, "Badge does not exist or has no expiry");
        _expiry[tokenId] = block.timestamp + newExpiryDuration;
        emit ExpiryExtended(tokenId, _expiry[tokenId]);
    }

    function setDefaultExpiryDuration(uint256 duration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        expiryDuration = duration;
    }

    /**
     * @dev Mints Employee Level Badge to a builder
     * @param to Address to receive badges
     * @param amount Number of badges to mint (max 6)
     * @param customExpiryDuration 
     */
    function mintEmployeeLevelBadge(
        address to,
        uint256 amount,
        uint256 customExpiryDuration
    )
        external
        onlyBuilderTokenHolder
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(amount <= WALLET_CAP, "Exceeds wallet cap");
        require(to != address(0), "Cannot mint to zero address");

        _mint(to, amount);
        // holder.expiry = block.timestamp + BADGE_EXPIRY;
        holder.mintTime = block.timestamp;

        // _expiry[tokenId] = block.timestamp + (customExpiryDuration > 0 ? customExpiryDuration : expiryDuration);
        // emit BadgeExpired(tokenId, _expiry[tokenId]);

        emit Transfer(address(0), to, amount);
    }


    /**
     * @dev Burns expired badges
     * @param from Address to burn badges from
     * @param amount Number of badges to burn
     */
    function burnExpiredBadges(address from, uint256 amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");

        BadgeHolder storage holder = _badgeHolders[from];
        require(block.timestamp >= holder.expiry, "Badges not expired");
        require(balanceOf(from) >= amount, "Insufficient balance");

        _burn(from, amount);
        holder.expiry = 0;
    }

    /**
     * @dev Checks if a holder has a specific badge
     * @param holder Address to check
     * @param badgeType Badge type to check for
     * @return bool True if holder has the badge
     */
    function hasBadge(address holder, uint256 badgeType) public view returns (bool) {
        return (_badgeHolders[holder].badgeTypes & badgeType) != 0;
    }

    /**
     * @dev Gets badge expiry for a holder
     * @param holder Address to check
     * @return uint256 Expiry timestamp
     */
    function getBadgeExpiry(address holder) public view returns (uint256) {
        return _badgeHolders[holder].expiry;
    }

    /**
     * @dev Override transfer to enforce soulbound behavior
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0)) {
            require(to == address(0) || to == from, "Badges are soulbound");
        }
    }

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     uint256
    // ) internal virtual override {
    //     super._beforeTokenTransfer(from, to, tokenId, 1);
    //     require(!isExpired(tokenId), "Cannot transfer expired badge");
    // }

}