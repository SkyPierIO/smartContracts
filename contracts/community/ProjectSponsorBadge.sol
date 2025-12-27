// contracts/community/ProjectSponsorBadge.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");

        uint256 tokenId = _nextTokenId++;
        uint256 expiry = block.timestamp + duration;

        _mint(to, tokenId, 1, expiry, "");

        _projectInfo[tokenId] = ProjectInfo({
            projectId: projectId,
            startTime: block.timestamp,
            endTime: expiry,
            sponsor: to
        });

        emit TransferSingle(msg.sender, address(0), to, tokenId, 1);
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
     * @return bool True if badge is still valid
     */
    function isValidBadge(uint256 tokenId) public view returns (bool) {
        return block.timestamp <= getExpiry(tokenId);
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