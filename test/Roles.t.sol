// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Roles} from "../src/lib/Roles.sol";

/// @notice Pins the role ids, which the deploy script and the Safe's transactions depend on.
contract RolesTest is Test {
    function test_DefaultAdminIsAccessControlZero() public pure {
        assertEq(Roles.DEFAULT_ADMIN_ROLE, bytes32(0));
    }

    function test_RoleIdsAreKeccakOfName() public pure {
        assertEq(Roles.UPGRADER_ROLE, keccak256("UPGRADER_ROLE"));
        assertEq(Roles.PAUSER_ROLE, keccak256("PAUSER_ROLE"));
        assertEq(Roles.MINTER_ROLE, keccak256("MINTER_ROLE"));
        assertEq(Roles.OPERATOR_ROLE, keccak256("OPERATOR_ROLE"));
        assertEq(Roles.VALIDATOR_ROLE, keccak256("VALIDATOR_ROLE"));
    }

    function test_RoleIdsAreDistinct() public pure {
        bytes32[6] memory ids = [
            Roles.DEFAULT_ADMIN_ROLE,
            Roles.UPGRADER_ROLE,
            Roles.PAUSER_ROLE,
            Roles.MINTER_ROLE,
            Roles.OPERATOR_ROLE,
            Roles.VALIDATOR_ROLE
        ];
        for (uint256 i = 0; i < ids.length; i++) {
            for (uint256 j = i + 1; j < ids.length; j++) {
                assertTrue(ids[i] != ids[j]);
            }
        }
    }
}
