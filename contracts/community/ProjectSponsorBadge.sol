// contracts/community/ProjectSponsorBadge.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../lib/ExpiryManagement.sol";

contract ProjectSponsorBadge is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using ExpiryManagement for ExpiryManagement.ExpiryInfo;

    uint256 public constant SPONSOR_BADGE = 0;
    uint256 public constant BADGE_EXPIRY = 52 weeks;

    struct ProjectInfo {
        string projectId;
        uint256 startTime;
        uint256 endTime;
        address sponsor;
    }

    mapping(uint256 => ProjectInfo) private _projectInfo;
    mapping(uint256 => ExpiryManagement.ExpiryInfo) private _expiryInfo;

    event BadgeMinted(
        uint256 indexed tokenId,
        string projectId,
        address sponsor,
        uint256 expiry
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/sponsor/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints a project sponsor badge
     * @param to Address to receive the badge
     * @param projectId ID of the project
     * @param duration Duration of the project in seconds
     */
    function mintSponsorBadge(
        address to,
        string memory projectId,
        uint256 duration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        if (duration == 0) duration = BADGE_EXPIRY; // Default to 52 weeks
        require(duration > 0, "Duration must be > 0");

        uint256 tokenId = uint256(keccak256(abi.encodePacked(projectId, to, block.timestamp)));
        uint256 expiry = block.timestamp + duration;

        _mint(to, tokenId, 1, "");
        _expiryInfo[tokenId].setExpiryAbsolute(uint64(expiry));

        _projectInfo[tokenId] = ProjectInfo({
            projectId: projectId,
            startTime: block.timestamp,
            endTime: expiry,
            sponsor: to
        });

        emit BadgeMinted(tokenId, projectId, to, expiry);
    }

    /**
     * @dev Gets project info for a badge
     * @param tokenId ID of the token
     * @return ProjectInfo Project information
     */
    function getProjectInfo(uint256 tokenId) public view returns (ProjectInfo memory) {
        return _projectInfo[tokenId];
    }

    /**
     * @dev Checks if a badge is still valid
     * @param tokenId ID of the token
     * @return bool True if badge is still valid, false otherwise
     */
    function isValidBadge(uint256 tokenId) public view returns (bool) {
        return _expiryInfo[tokenId].isValid();
    }

    /**
     * @dev Enforce soulbound semantics: no transfers except burn/mint
     */
    function _beforeTokenTransfer(
        address /*operator*/,
        address from,
        address to,
        uint256[] memory /*ids*/,
        uint256[] memory /*amounts*/,
        bytes memory /*data*/
    ) internal {
        require(from == address(0) || to == address(0), "Sponsor badge is soulbound");
    }

    /**
     * @dev Support AccessControl interface
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