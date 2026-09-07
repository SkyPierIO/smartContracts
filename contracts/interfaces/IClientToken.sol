// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IClientToken {
    // --- Events ---
    event BadgeIssued(address indexed account, uint256 indexed tokenId, uint256 amount, string metadata);
    event BadgeRevoked(address indexed account, uint256 indexed tokenId, uint256 amount);

    // --- Core Functions ---
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        string calldata metadata
    ) external;

    function burn(
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