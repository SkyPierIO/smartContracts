// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Roles
/// @notice AccessControl role ids used by the Core MVP contracts.
/// @dev Each id is keccak256 of the role's name, the OpenZeppelin convention, except DEFAULT_ADMIN_ROLE,
/// which is AccessControl's own 0x00. The admin Safe holds DEFAULT_ADMIN_ROLE, UPGRADER_ROLE and PAUSER_ROLE
/// on every contract; the deployer keeps none. Roles for Pre-mainnet and Phase 2 are added when those
/// contracts are built.
library Roles {
    /// @notice Admin of every other role. Changes settings, posts Merkle roots, whitelists operators,
    /// grants validators, moves Client tokens and unpauses. Held by the admin Safe only.
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Authorises UUPS upgrades. Held by the admin Safe; kept apart from admin so upgrades can move
    /// behind a timelock later without touching other permissions.
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Pauses PaymentPool. Only DEFAULT_ADMIN_ROLE unpauses. Held by the admin Safe in the MVP, so a
    /// pause-only monitoring key can be added later without an upgrade.
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Mints and extends Client tokens on ClientToken. Held by the PaymentPool contract.
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice The operator whitelist on SkypierVPN. Granted and revoked by the admin Safe. A node counts as
    /// operational only while its operator holds this role.
    bytes32 internal constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Validates new nodes on SkypierVPN. Held by staff wallets in the MVP, with no stake and no
    /// Network Pool share.
    bytes32 internal constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
}
