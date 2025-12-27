// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC3525/ERC3525.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectSponsorBadge is ERC3525, Ownable {
    struct Sponsorship {
        address sponsoredToken; // Address of the ERC1155 token being sponsored (e.g., Client Token)
        uint256 tokenId;        // ID of the sponsored token
        uint64 expiry;          // Expiry timestamp (52 weeks after delivery)
        bool isActive;          // Sponsorship status
    }

    mapping(uint256 => Sponsorship) private _sponsorships;

    event SponsorshipCreated(
        uint256 indexed badgeId,
        address indexed sponsoredToken,
        uint256 tokenId,
        uint64 expiry
    );

    constructor() ERC3525("ProjectSponsorBadge", "PSB") {}

    // Mint a sponsorship badge for a specific ERC1155 token
    function sponsorToken(
        address sponsoredToken,
        uint256 tokenId,
        uint64 duration // Duration in seconds (e.g., 52 weeks)
    ) external onlyOwner {
        require(sponsoredToken != address(0), "Invalid token address");
        uint256 badgeId = _nextId();
        uint64 expiry = block.timestamp + duration;

        _sponsorships[badgeId] = Sponsorship({
            sponsoredToken: sponsoredToken,
            tokenId: tokenId,
            expiry: expiry,
            isActive: true
        });

        _mint(msg.sender, badgeId, expiry, "", false);
        emit SponsorshipCreated(badgeId, sponsoredToken, tokenId, expiry);
    }

    // Check if a badge is active
    function isActive(uint256 badgeId) public view returns (bool) {
        return _sponsorships[badgeId].isActive;
    }

    // Get sponsored token details
    function getSponsoredToken(uint256 badgeId)
        public
        view
        returns (address, uint256, uint64)
    {
        Sponsorship memory sponsorship = _sponsorships[badgeId];
        return (sponsorship.sponsoredToken, sponsorship.tokenId, sponsorship.expiry);
    }

    // Override tokenExpiry to return the sponsorship expiry
    function tokenExpiry(uint256 tokenId) public view override returns (uint64) {
        return _sponsorships[tokenId].expiry;
    }
}