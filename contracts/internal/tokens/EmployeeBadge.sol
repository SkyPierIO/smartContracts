// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccessControlledUpgradeableToken} from "../../lib/BaseAccessControlledUpgradeableToken.sol";
import {ExpiryManagement} from "../../lib/ExpiryManagement.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title EmployeeLevelBadge
 * @dev ERC1155 upgradeable employee badge with expiry and wallet cap
 */
contract EmployeeLevelBadge is Initializable, BaseAccessControlledUpgradeableToken {
    uint256 public constant WALLET_CAP = 6;

    using ExpiryManagement for ExpiryManagement.ExpiryInfo;

    struct BadgeHolder {
        uint256 mintTime;
    }

    mapping(address => BadgeHolder) private _badgeHolders;
    mapping(address => uint256) private _lastClaim;

    address public builderToken;
    uint256 public builderTokenId;

    mapping(uint256 => ExpiryManagement.ExpiryInfo) private _expiry;
    uint256 public expiryDuration;

    uint256 private _nextTokenId;

    event BadgeExpired(uint256 indexed tokenId, uint256 expiryTime);
    event ExpiryExtended(uint256 indexed tokenId, uint256 newExpiryTime);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory uri,
        address _builderToken,
        uint256 _builderTokenId,
        uint256 _expiryDuration,
        address admin
    ) public initializer {
        __BaseAccessControlledUpgradeableToken_init(uri);
        builderToken = _builderToken;
        builderTokenId = _builderTokenId;
        expiryDuration = _expiryDuration;
        if (admin != msg.sender) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }
    }

    modifier onlyBuilderTokenHolder() {
        require(
            IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token"
        );
        _;
    }

    function isExpired(uint256 tokenId) public view returns (bool) {
        return _expiry[tokenId].isExpired();
    }

    function extendExpiry(uint256 tokenId, uint256 additionalDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _expiry[tokenId].extendExpiry(additionalDuration);
        emit ExpiryExtended(tokenId, _expiry[tokenId].expiryTime);
    }

    function setDefaultExpiryDuration(uint256 duration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        expiryDuration = duration;
    }

    function mintEmployeeLevelBadge(
        address to,
        uint256 amount,
        uint256 customExpiryDuration
    ) external onlyBuilderTokenHolder onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= WALLET_CAP, "Exceeds wallet cap");
        require(to != address(0), "Cannot mint to zero address");

        uint256 tokenId = _nextTokenId++;
        _safeMintWithRole(to, tokenId, amount, "");

        uint256 dur = customExpiryDuration > 0 ? customExpiryDuration : expiryDuration;
        _expiry[tokenId].setExpiry(dur);
        emit BadgeExpired(tokenId, _expiry[tokenId].expiryTime);
    }

    function burnExpiredBadges(address from, uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_expiry[tokenId].isExpired(), "Badges not expired");
        _safeBurnWithRole(from, tokenId, 1);
        _expiry[tokenId].revokeExpiry();
    }

    function hasBadge(address holder, uint256 tokenId) public view returns (bool) {
        return balanceOf(holder, tokenId) > 0;
    }

    function getBadgeExpiry(uint256 tokenId) public view returns (uint256) {
        return _expiry[tokenId].expiryTime;
    }

    function _beforeTokenTransfer(
        address /*operator*/,
        address from,
        address to,
        uint256[] memory /*ids*/,
        uint256[] memory /*amounts*/,
        bytes memory /*data*/
    ) internal {
        require(from == address(0) || to == address(0), "Badges are soulbound");
    }

}