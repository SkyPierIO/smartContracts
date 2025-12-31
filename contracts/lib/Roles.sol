// ========== Roles ==========
/**
 * @dev Library to define all Roles and Badges in Skypier.
 * Defines access permissions for all Roles and Badges in Skypier's Role-based access control (RBAC) .
 */
library Roles {
    /// @dev Admin Badge - can access everything & Token/Badge ID
    bytes32 public constant ADMIN_BADGE = keccak256("ADMIN_BADGE");
    uint256 public constant ADMIN_BADGE_ID = 0;

    /// @dev Operator role - can use nodes & Token/Badge ID
    bytes32 public constant CLIENT_ROLE = keccak256("CLIENT_ROLE");
    uint256 public constant CLIENT_TOKEN_ID = 1;
    
    /// @dev Operator role - can manage nodes & Token/Badge ID
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant OPERATOR_TOKEN_ID = 2;
     
    /// @dev Validator role - can validate operators & Token/Badge ID
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    uint256 public constant VALIDATOR_TOKEN_ID = 3;

    /// @dev Builder role - can manage system parameters & Token/Badge ID
    bytes32 public constant BUILDER_ROLE = keccak256("BUILDER_ROLE");
    uint256 public constant BUILDER_TOKEN_ID = 4;

    /// @dev Employee badge - can affect everyone else except Admin & Token/Badge ID
    bytes32 public constant EMPLOYEE_BADGE = keccak256("EMPLOYEE_BADGE");
    uint256 public constant EMPLOYEE_BADGE_ID = 5;
    // All Annualized badge IDs will be an addition to the 10x EMPLOYEE_BADGE_ID, e.g. 51, 52, 53, etc 

    /// @dev Beta Tester badge - can assign/revoke beta tester badges & Token/Badge ID
    bytes32 public constant BETA_TESTER_BADGE = keccak256("BETA_TESTER_BADGE");
    uint256 public constant BETA_TESTER_BADGE_ID = 6;

    /// @dev Project Sponsor badge - can assign/revoke builder badges & Token/Badge ID
    bytes32 public constant PROJECT_SPONSOR_BADGE = keccak256("PROJECT_SPONSOR_BADGE");
    uint256 public constant PROJECT_SPONSOR_BADGE_ID = 7;
}
