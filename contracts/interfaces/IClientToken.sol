// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClientToken {
    // --- Events ---
    event BadgeIssued(address indexed account, uint256 indexed tokenId, uint256 amount, string metadata);
    event BadgeRevoked(address indexed account, uint256 indexed tokenId, uint256 amount);

    // --- Core Functions ---
    function issueBadge(
        address to,
        uint256 tokenId,
        uint256 amount,
        uint64 expiryTimestamp
    ) external;

    function revokeBadge(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external;

    function isValidHolder(address user, uint256 tokenId) external view returns (bool);

    function getExpiry(uint256 tokenId) external view returns (uint64);

    // --- Token IDs (optional, but useful for clarity) ---
    function CLIENT_BADGE() external view returns (uint256);
    function BETA_TESTER_BADGE() external view returns (uint256);
}