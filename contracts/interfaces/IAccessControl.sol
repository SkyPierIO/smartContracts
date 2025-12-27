// contracts/interfaces/IAccessControl.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessControl {
    // Role identifiers
    bytes32 public constant BUILDER_ROLE = keccak256("BUILDER_ROLE");
    bytes32 public constant QA_BADGE = keccak256("QA_BADGE");
    bytes32 public constant ADMIN_BADGE = keccak256("ADMIN_BADGE");

    // Role management
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}