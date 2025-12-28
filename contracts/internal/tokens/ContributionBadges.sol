// contracts/internal/tokens/ContributionBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract ContributionBadges is ERC20, AccessControl {
    uint256 public constant WALLET_CAP = 6;
    uint256 public constant BADGE_EXPIRY = 78 weeks;

    struct BadgeHolder {
        uint256 badgeTypes; // Bitmask of badge types
        uint256 expiry;     // Expiry timestamp
        uint256 mintTime;   // When the badge was minted
    }

    mapping(address => BadgeHolder) private _badgeHolders;
    mapping(address => uint256) private _lastClaim;

    constructor() ERC20("Skypier Contribution Badges", "SCB") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints contribution badges to a builder
     * @param to Address to receive badges
     * @param amount Number of badges to mint (max 6)
     * @param badgeType Type of badge (bitmask)
     */
    function mintContributionBadges(
        address to,
        uint256 amount,
        uint256 badgeType
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(amount <= WALLET_CAP, "Exceeds wallet cap");
        require(badgeType != 0, "Invalid badge type");

        BadgeHolder storage holder = _badgeHolders[to];
        require(holder.badgeTypes + badgeType <= WALLET_CAP, "Exceeds badge limit");

        _mint(to, amount);
        holder.badgeTypes |= badgeType;
        holder.expiry = block.timestamp + BADGE_EXPIRY;
        holder.mintTime = block.timestamp;

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
        holder.badgeTypes = 0;
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
}