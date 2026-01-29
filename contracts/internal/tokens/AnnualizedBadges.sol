// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccessControlledUpgradeableToken} from "../../lib/BaseAccessControlledUpgradeableToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


/**
 * @title AnnualizedBadges
 * @dev Upgradeable ERC1155 for annualized badges using shared base
 */
contract AnnualizedBadges is Initializable, BaseAccessControlledUpgradeableToken {
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

    address public builderToken;
    uint256 public builderTokenId;

    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory uri, address _builderToken, uint256 _builderTokenId, address admin) public initializer {
        __BaseAccessControlledUpgradeableToken_init(uri);
        builderToken = _builderToken;
        builderTokenId = _builderTokenId;
        if (admin != msg.sender) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }
    }

    modifier onlyBuilderTokenHolder() {
        require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0, "Must hold Builder Token");
        _;
    }

    function awardBadge(address to, uint256 badgeId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyBuilderTokenHolder {
        require(badgeId <= BUG_CATCHER_BADGE, "Invalid badge ID");
        require(!_hasBadge[to][badgeId], "Already has this badge");

        uint256 tokenId = _nextTokenId++;
        _safeMintWithRole(to, tokenId, 1, "");

        _badgeInfo[tokenId][badgeId] = BadgeInfo({
            holder: to,
            nominatedBy: msg.sender,
            awardedAt: block.timestamp,
            expiresAt: block.timestamp + BADGE_EXPIRY
        });

        _hasBadge[to][badgeId] = true;
    }

    function revokeExpiredBadge(address from, uint256 badgeId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tokenId = _findTokenId(from, badgeId);
        require(tokenId != 0, "Badge not found");
        require(block.timestamp >= _badgeInfo[tokenId][badgeId].expiresAt, "Badge not expired");

        _safeBurnWithRole(from, tokenId, 1);
        _hasBadge[from][badgeId] = false;
    }

    function hasBadge(address holder, uint256 badgeId) public view returns (bool) {
        return _hasBadge[holder][badgeId];
    }

    function getBadgeExpiry(address holder, uint256 badgeId) public view returns (uint256) {
        uint256 tokenId = _findTokenId(holder, badgeId);
        require(tokenId != 0, "Badge not found");
        return _badgeInfo[tokenId][badgeId].expiresAt;
    }

    function _findTokenId(address holder, uint256 badgeId) internal view returns (uint256) {
        // naive scan over produced token IDs
        for (uint256 i = 0; i < _nextTokenId; i++) {
            if (_badgeInfo[i][badgeId].holder == holder) {
                return i;
            }
        }
        return 0;
    }
}
