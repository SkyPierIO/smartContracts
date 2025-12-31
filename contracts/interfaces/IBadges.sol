// contracts/interfaces/IBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface for the Skypier Badges contract.
 * Defines the core functionality for for all Skypier ancillary badges.
 */
interface IBadges {
    // Badge types
    struct BadgeAttributes {
        address holder;
        address issuedBy;
        uint256 issuedAt;
        uint256 expiresAt;
    }

    // Core badge functions
    function mintBadge(
        address to,
        uint256 badgeId,
        uint256 amount,
        bytes memory data
    ) external;

    function revokeBadge(address from, uint256 badgeId) external;

    function getBadgeAttributes(uint256 badgeId, address holder)
        external
        view
        returns (BadgeAttributes memory);
}