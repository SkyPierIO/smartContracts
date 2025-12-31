// contracts/internal/tokens/AnnualizedBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AnnualizedBadges is ERC1155, AccessControl, ReentrancyGuard {
    // Badge IDs
    uint256 public constant TECHNICAL_FELLOW_BADGE = 0;
    uint256 public constant MENTOR_BADGE = 1;
    uint256 public constant PROJECT_LEAD_BADGE = 2;
    uint256 public constant PEOPLE_LEAD_BADGE = 3;
    uint256 public constant TRAILBLAZER_BADGE = 4;
    uint256 public constant TEAM_SAGE_BADGE = 5;
    uint256 public constant CLUTCH_BADGE = 6;
    uint256 public constant HUSTLE_BADGE = 7;
    uint256 public constant BUG_CATCHER_BADGE = 8;

    uint256 public constant BADGE_EXPIRY = 52 weeks;

    struct BadgeInfo {
        address holder;
        address nominatedBy;
        uint256 awardedAt;
        uint256 expiresAt;
    }

    mapping(uint256 => mapping(uint256 => BadgeInfo)) private _badgeInfo;
    mapping(address => mapping(uint256 => bool)) private _hasBadge;

    IERC1155 public immutable builderToken;
    uint256 public immutable builderTokenId;

    constructor(address _builderToken, uint256 _builderTokenId)
        ERC1155("https://skypier.io/annualized/{id}.json")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        builderToken = IERC1155(_builderToken);
        builderTokenId = _builderTokenId;
    }

    modifier onlyBuilderTokenHolder() {  // EMPLOYEE_BADGE Only
        require(
            builderToken.balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token"
        );
        _;
    }

    // function mintAnnualizedBadge(address to, uint256 amount)
    //     external
    //     onlyBuilderTokenHolder
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    //     nonReentrant
    // {
    //     require(to != address(0), "Cannot mint to zero address");
    //     _mint(to, _nextId(), amount, "");
    // }

    /**
     * @dev Awards an annualized badge to a holder
     * @param to Address to receive the badge
     * @param badgeId ID of the badge to award
     */
    function awardBadge(address to, uint256 badgeId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(badgeId <= BUG_CATCHER_BADGE, "Invalid badge ID");
        require(!_hasBadge[to][badgeId], "Already has this badge");

        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId, 1, "");

        _badgeInfo[tokenId][badgeId] = BadgeInfo({
            holder: to,
            nominatedBy: msg.sender,
            awardedAt: block.timestamp,
            expiresAt: block.timestamp + BADGE_EXPIRY
        });

        _hasBadge[to][badgeId] = true;

        emit TransferSingle(msg.sender, address(0), to, tokenId, 1);
    }

    /**
     * @dev Revokes an expired badge
     * @param from Address to revoke badge from
     * @param badgeId ID of the badge to revoke
     */
    function revokeExpiredBadge(address from, uint256 badgeId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");

        uint256 tokenId = _findTokenId(from, badgeId);
        require(tokenId != 0, "Badge not found");
        require(block.timestamp >= _badgeInfo[tokenId][badgeId].expiresAt, "Badge not expired");

        _burn(from, tokenId, 1);
        _hasBadge[from][badgeId] = false;
    }

    /**
     * @dev Checks if a holder has a specific badge
     * @param holder Address to check
     * @param badgeId ID of the badge to check
     * @return bool True if holder has the badge
     */
    function hasBadge(address holder, uint256 badgeId) public view returns (bool) {
        return _hasBadge[holder][badgeId];
    }

    /**
     * @dev Gets badge expiry for a holder
     * @param holder Address to check
     * @param badgeId ID of the badge to check
     * @return uint256 Expiry timestamp
     */
    function getBadgeExpiry(address holder, uint256 badgeId) public view returns (uint256) {
        uint256 tokenId = _findTokenId(holder, badgeId);
        require(tokenId != 0, "Badge not found");
        return _badgeInfo[tokenId][badgeId].expiresAt;
    }

    /**
     * @dev Internal helper to find token ID for a badge
     */
    function _findTokenId(address holder, uint256 badgeId) internal view returns (uint256) {
        uint256 supply = totalSupply(badgeId);
        for (uint256 i = 0; i < supply; i++) {
            if (_badgeInfo[i][badgeId].holder == holder) {
                return i;
            }
        }
        return 0;
    }
}