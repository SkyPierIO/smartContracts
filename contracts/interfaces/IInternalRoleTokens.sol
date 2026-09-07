// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IInternalRoleTokens {
    function mintBuilderToken(address to) external;
    function mintEmployeeLevelBadge(address to, uint256 amount, uint256 customExpiryDuration) external;
    function mintAdminBadge(address to) external;
}
