// contracts/community/ProjectSponsorBadge.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC3525/ERC3525.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ProjectSponsorBadge is ERC3525, AccessControl {
    uint256 public constant SPONSOR_BADGE = 0;
    uint256 public constant BADGE_EXPIRY = 52 weeks;

    struct ProjectInfo {
        string projectId;
        uint256 startTime;
        uint256 endTime;
        address sponsor;
    }

    mapping(uint256 => ProjectInfo) private _projectInfo;

    event BadgeMinted(
        uint256 indexed tokenId,
        string projectId,
        address sponsor,
        uint256 expiry
    );

    constructor() ERC3525("https://skypier.io/sponsor/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
    ) external {
        require(to != address(0), "Invalid recipient");
        require(duration > 0, "Duration must be > 0");
        if (duration == 0) duration = BADGE_EXPIRY; // Default to 52 weeks
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");

        uint256 tokenId = keccak256(abi.encodePacked(projectId, sponsor));
        uint256 expiry = block.timestamp + duration;

        _mint(to, tokenId, 1, expiry, "");

        _projectInfo[tokenId] = ProjectInfo({
            projectId: projectId,
            startTime: block.timestamp,
            endTime: expiry,
            sponsor: to
        });

        // Emit in mintSponsorBadge:
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
        ProjectInfo memory info = _projectInfo[tokenId];
        return block.timestamp <= info.endTime;
    }

    /**
     * @dev Override transfer to enforce soulbound behavior
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from != address(0)) {
            require(to == address(0) || to == from, "Sponsor badge is soulbound");
        }
    }
}