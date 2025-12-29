// ========== Roles ==========

library Roles {
    /// @dev Operator role - can manage nodes
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @dev Validator role - can validate operators
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    /// @dev Builder role - can manage system parameters
    bytes32 public constant BUILDER_ROLE = keccak256("BUILDER_ROLE");

    /// @dev QA role - can assign/revoke beta tester badges
    bytes32 public constant QA_ROLE = keccak256("QA_ROLE");
}
