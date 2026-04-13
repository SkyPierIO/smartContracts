# Skypier Smart Contract - Persona and Role-Based Access Control Analysis

## System Overview

The Skypier system implements a sophisticated role-based access control (RBAC) system with 8 personas, each with specific permissions and related token/badge contracts. All personas are defined in [Roles.sol](contracts/lib/Roles.sol).

---

## PERSONA DEFINITIONS

| Persona | Role Identifier | Token ID | Purpose |
|---------|-----------------|----------|---------|
| ADMIN_BADGE | `keccak256("ADMIN_BADGE")` | 0 | Can access everything |
| CLIENT_ROLE | `keccak256("CLIENT_ROLE")` | 1 | Can use nodes |
| OPERATOR_ROLE | `keccak256("OPERATOR_ROLE")` | 2 | Can manage nodes |
| VALIDATOR_ROLE | `keccak256("VALIDATOR_ROLE")` | 3 | Can validate operators |
| BUILDER_ROLE | `keccak256("BUILDER_ROLE")` | 4 | Can manage system parameters |
| EMPLOYEE_BADGE | `keccak256("EMPLOYEE_BADGE")` | 5 | Can affect everyone except Admin |
| BETA_TESTER_BADGE | `keccak256("BETA_TESTER_BADGE")` | 6 | Can assign/revoke beta tester badges |
| PROJECT_SPONSOR_BADGE | `keccak256("PROJECT_SPONSOR_BADGE")` | 7 | Can assign/revoke builder badges |

---

## DETAILED PERSONA ANALYSIS

### 1. ADMIN_BADGE (Token ID 0)

**Contracts Handling:**
- [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol) - Minting and management
- [PaymentPool.sol](contracts/product/PaymentPool.sol) - System parameter control
- [BaseAccessControlledUpgradeableToken.sol](contracts/lib/BaseAccessControlledUpgradeableToken.sol) - Base access control

**Initialization Flow:**
1. Requires possession of `BUILDER_TOKEN` (prerequisite)
   - See [AdminBadge.sol#L44](contracts/internal/tokens/AdminBadge.sol#L44): `modifier onlyBuilderTokenHolder()`
2. Token can only be minted by existing admins
   - See [AdminBadge.sol#L47-L55](contracts/internal/tokens/AdminBadge.sol#L47-L55): `mintAdminBadge()` function

**Operations Allowed:**
- Mint new admin badges (if builder token holder)
  - [AdminBadge.sol#L47](contracts/internal/tokens/AdminBadge.sol#L47)
- Burn/revoke admin badges
  - [AdminBadge.sol#L60](contracts/internal/tokens/AdminBadge.sol#L60)
- Pause/unpause token contracts
  - [BaseAccessControlledUpgradeableToken.sol#L56-L62](contracts/lib/BaseAccessControlledUpgradeableToken.sol#L56-L62)
- Set token expiry times
  - [ClientToken.sol#L82](contracts/product/tokens/ClientToken.sol#L82)
- Revoke operators
  - [SkypierVPN.sol#L110-L116](contracts/product/SkypierVPN.sol#L110-L116)
- Manage payment pool parameters
  - [PaymentPool.sol#L361](contracts/product/PaymentPool.sol#L361)

**Soulbound Nature:**
- Admin badges are soulbound (non-transferable)
  - See [AdminBadge.sol#L68-L76](contracts/internal/tokens/AdminBadge.sol#L68-L76): `_beforeTokenTransfer()`

**Dependencies:**
- **Precondition**: Must hold BUILDER_BADGE (Token ID = 0 from BuilderToken)
- **Related**: Grants DEFAULT_ADMIN_ROLE on minting
  - [AdminBadge.sol#L52](contracts/internal/tokens/AdminBadge.sol#L52)

---

### 2. CLIENT_ROLE (Token ID 1)

**Contracts Handling:**
- [ClientToken.sol](contracts/product/tokens/ClientToken.sol) - Minting and badge management
- [PaymentPool.sol](contracts/product/PaymentPool.sol) - Payment tracking

**Initialization Flow:**
1. Users receive CLIENT_BADGE through payment (payForAccess)
   - See [PaymentPool.sol#L125-L131](contracts/product/PaymentPool.sol#L125-L131)
2. Token ID is 1 as defined in [ClientToken.sol#L30](contracts/product/tokens/ClientToken.sol#L30)
3. No expiry by default (expiry = 0)
   - See [PaymentPool.sol#L131](contracts/product/PaymentPool.sol#L131): `clientToken.issueToken(msg.sender, clientToken.CLIENT_ROLE(), 1, 0)`

**Operations Allowed:**
- Use VPN nodes (base access right)
- Submit payments to receive CLIENT_BADGE
  - [PaymentPool.sol#L125-L131](contracts/product/PaymentPool.sol#L125-L131): `payForAccess()`
- Deposit additional client payments
  - [PaymentPool.sol#L133-L139](contracts/product/PaymentPool.sol#L133-L139): `depositClientPayment()`

**Soulbound Nature:**
- CLIENT_BADGE is soulbound (non-transferable)
  - See [ClientToken.sol#L96-L104](contracts/product/tokens/ClientToken.sol#L96-L104): `_update()` override

**Minting Access Control:**
- Only accounts with MINTER_ROLE can mint
  - [ClientToken.sol#L66-L72](contracts/product/tokens/ClientToken.sol#L66-L72)

**Dependencies:**
- **Trigger**: Must submit payment (paymentAmount in tokens)
- **Revocation**: Can be burned by BURNER_ROLE
  - [ClientToken.sol#L75-L80](contracts/product/tokens/ClientToken.sol#L75-L80)

---

### 3. OPERATOR_ROLE (Token ID 2)

**Contracts Handling:**
- [OperatorToken.sol](contracts/product/tokens/OperatorToken.sol) - Node operator management
- [SkypierVPN.sol](contracts/product/SkypierVPN.sol) - Operator lifecycle and validation

**Initialization Flow:**
1. User applies to become operator via `applyAsOperator()`
   - [SkypierVPN.sol#L75-L82](contracts/product/SkypierVPN.sol#L75-L82)
2. Application adds user to waitlist with peer ID
3. VALIDATOR_ROLE must validate the operator
   - See section on VALIDATOR_ROLE below
4. Upon validation, operator registered in nodes mapping
   - [SkypierVPN.sol#L92-L107](contracts/product/SkypierVPN.sol#L92-L107)

**Operations Allowed:**
- Register/apply as node operator
  - [SkypierVPN.sol#L75](contracts/product/SkypierVPN.sol#L75)
- Maintain active node status
- Report heartbeats
- **Limited by**: VALIDATOR_ROLE approval required

**Token Structure:**
- One token per operator (1-to-1 mapping)
  - [OperatorToken.sol#L55-L67](contracts/product/tokens/OperatorToken.sol#L55-L67)
- Token stores nodeId and registration metadata
  - [OperatorToken.sol#L31-L36](contracts/product/tokens/OperatorToken.sol#L31-L36)

**Soulbound Nature:**
- Operator tokens are soulbound
  - See [OperatorToken.sol#L105-L113](contracts/product/tokens/OperatorToken.sol#L105-L113): `_beforeTokenTransfer()`

**Revocation:**
- ADMIN_ROLE can revoke operators
  - [SkypierVPN.sol#L110-L116](contracts/product/SkypierVPN.sol#L110-L116): `revokeOperator()`
- Deregistration marks operator as inactive
  - [OperatorToken.sol#L74-L79](contracts/product/tokens/OperatorToken.sol#L74-L79): `deregisterOperator()`

**Dependencies:**
- **Precondition**: Validator approval (VALIDATOR_ROLE)
- **Related Personas**: VALIDATOR_ROLE must validate, ADMIN_ROLE can revoke
- **Metrics Tracking**: PaymentPool records operator contributions
  - [PaymentPool.sol#L166-L180](contracts/product/PaymentPool.sol#L166-L180)

---

### 4. VALIDATOR_ROLE (Token ID 3)

**Contracts Handling:**
- [ValidatorToken.sol](contracts/product/tokens/ValidatorToken.sol) - Validator registration
- [SkypierVPN.sol](contracts/product/SkypierVPN.sol) - Operator validation logic

**Initialization Flow:**
1. Validator receives badge via `mintValidatorBadge()`
   - [ValidatorToken.sol#L47-L64](contracts/product/tokens/ValidatorToken.sol#L47-L64)
2. Requires staking amount (tracked in contract)
   - [ValidatorToken.sol#L52](contracts/product/tokens/ValidatorToken.sol#L52): `require(stakingAmount > 0)`
3. Stores ValidatorInfo with staking details
   - [ValidatorToken.sol#L55-L62](contracts/product/tokens/ValidatorToken.sol#L55-L62)

**Operations Allowed:**
- Validate (approve) operators
  - [SkypierVPN.sol#L92-L107](contracts/product/SkypierVPN.sol#L92-L107): `validateOperator()` with `onlyRole(VALIDATOR_ROLE)`
  - Must provide operator address and peerID
- Register peer ID during validation
- Marks operators as active in the network

**Access Control:**
- Only VALIDATOR_ROLE can call validateOperator()
  - [SkypierVPN.sol#L92](contracts/product/SkypierVPN.sol#L92)

**Token Structure:**
- One badge per validator (VALIDATOR_BADGE = 0)
  - [ValidatorToken.sol#L22](contracts/product/tokens/ValidatorToken.sol#L22)
- Soulbound token with isActive flag
  - [ValidatorToken.sol#L25-L31](contracts/product/tokens/ValidatorToken.sol#L25-L31)

**Revocation:**
- BURNER_ROLE can revoke validator badges
  - [ValidatorToken.sol#L66-L75](contracts/product/tokens/ValidatorToken.sol#L66-L75): `revokeValidatorBadge()`
- Marks validator as inactive

**Dependencies:**
- **Precondition**: Staking amount required (implicit economic requirement)
- **Function**: Validates OPERATOR_ROLE applications
- **Used By**: SkypierVPN contract for operator onboarding

---

### 5. BUILDER_ROLE (Token ID 4)

**Contracts Handling:**
- [BuilderToken.sol](contracts/internal/tokens/BuilderToken.sol) - Core builder token
- [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol) - Employee tracking (requires builder token)
- [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol) - Admin badge prerequisite
- [AnnualizedBadges.sol](contracts/internal/tokens/AnnualizedBadges.sol) - Annualized recognition (requires builder token)
- [HumanResources.sol](contracts/internal/HumanResources.sol) - Builder allocation tracking
- [PaymentPool.sol](contracts/product/PaymentPool.sol) - Builder payment distribution

**Initialization Flow:**
1. Admin mints BUILDER_BADGE token
   - [BuilderToken.sol#L28-L31](contracts/internal/tokens/BuilderToken.sol#L28-L31): `mintBuilderToken()`
   - Requires DEFAULT_ADMIN_ROLE
2. Builder registered in HumanResources
   - [HumanResources.sol#L57-L75](contracts/internal/HumanResources.sol#L57-L75): `registerBuilder()`
3. Monthly allocation assigned
   - [HumanResources.sol#L62](contracts/internal/HumanResources.sol#L62)

**Operations Allowed:**
- Mint employee badges
  - [EmployeeBadge.sol#L88-L99](contracts/internal/tokens/EmployeeBadge.sol#L88-L99): `mintEmployeeLevelBadge()`
  - Requires both builder token holder and admin role
- Award annualized badges
  - [AnnualizedBadges.sol#L60-L74](contracts/internal/tokens/AnnualizedBadges.sol#L60-L74): `awardBadge()`
- Create admin badges (if also builder token holder)
  - [AdminBadge.sol#L47-L55](contracts/internal/tokens/AdminBadge.sol#L47-L55)
- Manage system parameters in PaymentPool
  - [PaymentPool.sol#L396](contracts/product/PaymentPool.sol#L396): `require(hasRole(BUILDER_ROLE, msg.sender))`
- Register builders for payments
  - [PaymentPool.sol#L221](contracts/product/PaymentPool.sol#L221)

**Token Structure:**
- Single token (BUILDER_BADGE = 0)
  - [BuilderToken.sol#L12](contracts/internal/tokens/BuilderToken.sol#L12)
- Can be held with EMPLOYEE_BADGE and DEVELOPER_BADGE
  - [BuilderToken.sol#L13-L15](contracts/internal/tokens/BuilderToken.sol#L13-L15) - shows WALLET_CAP = 6

**Cross-Persona Dependencies:**
- **Enables**: ADMIN_BADGE creation (prerequisite - must hold builder token)
  - [AdminBadge.sol#L44](contracts/internal/tokens/AdminBadge.sol#L44)
- **Enables**: EMPLOYEE_BADGE minting
  - [EmployeeBadge.sol#L81](contracts/internal/tokens/EmployeeBadge.sol#L81)
- **Enables**: ANNUALIZED_BADGE awards
  - [AnnualizedBadges.sol#L52](contracts/internal/tokens/AnnualizedBadges.sol#L52)

**Payment Tracking:**
- Builders registered in PaymentPool with allocations
  - [PaymentPool.sol#L218-L227](contracts/product/PaymentPool.sol#L218-L227)
- Tracked separately from operators and validators
  - [PaymentPool.sol#L44](contracts/product/PaymentPool.sol#L44)

---

### 6. EMPLOYEE_BADGE (Token ID 5)

**Contracts Handling:**
- [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol) - Employee level badge management
- [AnnualizedBadges.sol](contracts/internal/tokens/AnnualizedBadges.sol) - Extended employee recognition

**Initialization Flow:**
1. Minted by builder token holder with admin role
   - [EmployeeBadge.sol#L88-L99](contracts/internal/tokens/EmployeeBadge.sol#L88-L99)
2. Requires builder token as prerequisite
   - [EmployeeBadge.sol#L81-L86](contracts/internal/tokens/EmployeeBadge.sol#L81-L86): `modifier onlyBuilderTokenHolder()`
3. Sets default expiry (52 weeks)
   - [EmployeeBadge.sol#L96](contracts/internal/tokens/EmployeeBadge.sol#L96)

**Operations Allowed:**
- Receive multiple employee level badges (up to 6)
  - [EmployeeBadge.sol#L14](contracts/internal/tokens/EmployeeBadge.sol#L14): `WALLET_CAP = 6`
- Track tenure and recognition
- Performance evaluation badges
- Expiry and renewal mechanism

**Token Structure:**
- Multiple tokens per holder (supports wallet cap of 6)
  - [EmployeeBadge.sol#L14](contracts/internal/tokens/EmployeeBadge.sol#L14)
- Soulbound (non-transferable)
  - [EmployeeBadge.sol#L113-L121](contracts/internal/tokens/EmployeeBadge.sol#L113-L121)
- Has expiry tracking
  - [EmployeeBadge.sol#L96](contracts/internal/tokens/EmployeeBadge.sol#L96)

**Expiry Management:**
- Default 52 weeks from minting
  - [EmployeeBadge.sol#L95-L96](contracts/internal/tokens/EmployeeBadge.sol#L95-L96)
- Can be extended by admin
  - [EmployeeBadge.sol#L64-L68](contracts/internal/tokens/EmployeeBadge.sol#L64-L68): `extendExpiry()`
- Expired badges can be burned
  - [EmployeeBadge.sol#L101-L105](contracts/internal/tokens/EmployeeBadge.sol#L101-L105): `burnExpiredBadges()`

**Revocation:**
- Burned when expired
- Only admin can burn
  - [EmployeeBadge.sol#L101](contracts/internal/tokens/EmployeeBadge.sol#L101): `onlyRole(DEFAULT_ADMIN_ROLE)`

**Dependencies:**
- **Precondition**: Must be minted by builder token holder
- **Related**: Can lead to ANNUALIZED_BADGE awards
  - [AnnualizedBadges.sol#L60](contracts/internal/tokens/AnnualizedBadges.sol#L60)
- **Limitation**: "Can affect everyone else except Admin"
  - Implies employee badges don't grant access to admin functions

---

### 7. BETA_TESTER_BADGE (Token ID 6)

**Contracts Handling:**
- [ClientToken.sol](contracts/product/tokens/ClientToken.sol) - Badge management
- [PaymentPool.sol](contracts/product/PaymentPool.sol) - Integration point

**Initialization Flow:**
1. Defined as badge ID 1 in ClientToken
   - [ClientToken.sol#L30](contracts/product/tokens/ClientToken.sol#L30)
2. Minted by MINTER_ROLE via mint() function
   - [ClientToken.sol#L66-L72](contracts/product/tokens/ClientToken.sol#L66-L72)
3. No built-in expiry by default

**Operations Allowed:**
- Early access to VPN features
- Special testing privileges
- Multiple badges can be held
- Can be burned by BURNER_ROLE
  - [ClientToken.sol#L75-L80](contracts/product/tokens/ClientToken.sol#L75-L80)

**Token Structure:**
- Token ID = 1 (BETA_TESTER_BADGE)
  - [ClientToken.sol#L30](contracts/product/tokens/ClientToken.sol#L30)
- Soulbound like CLIENT_BADGE
  - [ClientToken.sol#L96-L104](contracts/product/tokens/ClientToken.sol#L96-L104)
- Expiry can be set per token
  - [ClientToken.sol#L82-L84](contracts/product/tokens/ClientToken.sol#L82-L84): `setExpiry()`

**Revocation:**
- BURNER_ROLE can revoke
  - [ClientToken.sol#L75-L80](contracts/product/tokens/ClientToken.sol#L75-L80)
- Can expire if expiry time is set and reached
  - [ClientToken.sol#L86-L88](contracts/product/tokens/ClientToken.sol#L86-L88): `isExpired()`

**Dependencies:**
- **Can Be**: Assigned/revoked by those with MINTER_ROLE
- **Related To**: CLIENT_BADGE (both held in ClientToken)
- **Special Capability**: Can assign/revoke other beta tester badges (self-managing based on role)

---

### 8. PROJECT_SPONSOR_BADGE (Token ID 7)

**Contracts Handling:**
- [ProjectSponsorBadge.sol](contracts/community/ProjectSponsorBadge.sol) - Badge lifecycle management

**Initialization Flow:**
1. Minted by DEFAULT_ADMIN_ROLE
   - [ProjectSponsorBadge.sol#L54-L69](contracts/community/ProjectSponsorBadge.sol#L54-L69)
2. Associated with specific project ID
   - [ProjectSponsorBadge.sol#L61](contracts/community/ProjectSponsorBadge.sol#L61)
3. Default 52 weeks expiry (can be customized)
   - [ProjectSponsorBadge.sol#L58-L60](contracts/community/ProjectSponsorBadge.sol#L58-L60): `duration = BADGE_EXPIRY` if 0

**Operations Allowed:**
- Sponsor projects in the ecosystem
- Grant BUILDER_ROLE (implied capability)
- Project lifecycle tracking
- Time-limited sponsorships

**Token Structure:**
- Token ID derived from project ID and timestamp
  - [ProjectSponsorBadge.sol#L62](contracts/community/ProjectSponsorBadge.sol#L62)
- Soulbound (non-transferable)
  - [ProjectSponsorBadge.sol#L97-L105](contracts/community/ProjectSponsorBadge.sol#L97-L105)
- Has built-in expiry (52 weeks default)
  - [ProjectSponsorBadge.sol#L24](contracts/community/ProjectSponsorBadge.sol#L24)

**Project Information Stored:**
- Project ID
- Start and end times
- Sponsor address
  - [ProjectSponsorBadge.sol#L25-L30](contracts/community/ProjectSponsorBadge.sol#L25-L30)

**Validation:**
- Badges can be checked if still valid
  - [ProjectSponsorBadge.sol#L84-L88](contracts/community/ProjectSponsorBadge.sol#L84-L88): `isValidBadge()`

**Dependencies:**
- **Minter**: Only DEFAULT_ADMIN_ROLE
- **Related**: Can grant BUILDER_ROLE creation capability (implied)
- **Lifecycle**: Projects track via startTime/endTime

---

## CROSS-PERSONA DEPENDENCIES AND HIERARCHICAL RELATIONSHIPS

### Dependency Matrix

```
ADMIN_BADGE
├── Prerequisite: Must hold BUILDER_BADGE
├── Grants: DEFAULT_ADMIN_ROLE on all contracts
└── Revokes: Can revoke OPERATOR_ROLE, VALIDATOR_ROLE

BUILDER_BADGE
├── Created by: DEFAULT_ADMIN_ROLE only
├── Enables: ADMIN_BADGE creation
├── Enables: EMPLOYEE_BADGE minting
├── Enables: ANNUALIZED_BADGE awarding
└── Tracked in: HumanResources contract

CLIENT_ROLE
├── Trigger: Payment via PaymentPool
├── No prerequisites
└── Revokes: BURNER_ROLE

OPERATOR_ROLE
├── Requires: VALIDATOR_ROLE approval
├── Can be: Revoked by ADMIN_ROLE
├── Tracked in: PaymentPool for metrics
└── Manages: Node operations

VALIDATOR_ROLE
├── Prerequisite: Staking amount required
├── Function: Approves OPERATOR_ROLE applications
├── Revokes: BURNER_ROLE can revoke
└── Tracked in: PaymentPool

EMPLOYEE_BADGE
├── Prerequisite: BUILDER_BADGE holder
├── Created by: DEFAULT_ADMIN_ROLE (builder holder)
├── Expiry: 52 weeks default
├── Can be: Extended or burned
└── Leads to: ANNUALIZED_BADGE awards

BETA_TESTER_BADGE
├── Minted by: MINTER_ROLE
├── Revoked by: BURNER_ROLE
├── Optional expiry: Admin can set
└── Coexists with: CLIENT_BADGE

PROJECT_SPONSOR_BADGE
├── Minted by: DEFAULT_ADMIN_ROLE
├── Duration: 52 weeks (default)
├── Can be: Checked for validity
└── Related to: Project lifecycle tracking
```

### Hierarchical Flow

**Level 1: Ecosystem Gatekeepers**
- ADMIN_BADGE (top-level access)
- BUILDER_BADGE (enables internal operations)

**Level 2: Operational Roles**
- OPERATOR_ROLE (depends on VALIDATOR_ROLE)
- VALIDATOR_ROLE (independent, requires staking)
- CLIENT_ROLE (payment-driven, independent)

**Level 3: Employee/Recognition System**
- EMPLOYEE_BADGE (requires BUILDER_BADGE)
- ANNUALIZED_BADGES (requires BUILDER_BADGE)
- BETA_TESTER_BADGE (independent, payment optional)

**Level 4: Community/Project Support**
- PROJECT_SPONSOR_BADGE (admin-only, project-focused)

### Operational Flows

#### Operator Onboarding
```
User → applyAsOperator() 
     → [Waitlist] 
     → VALIDATOR_ROLE validates 
     → OPERATOR_ROLE activated 
     → PaymentPool tracks metrics
```
Reference: [SkypierVPN.sol#L75-L107](contracts/product/SkypierVPN.sol#L75-L107)

#### Builder Promotion Path
```
Admin → mintBuilderToken() 
     → registerBuilder() in HumanResources 
     → Can mint EMPLOYEE_BADGE 
     → Can award ANNUALIZED_BADGE 
     → Can create ADMIN_BADGE
```
References:
- [BuilderToken.sol#L28-L31](contracts/internal/tokens/BuilderToken.sol#L28-L31)
- [HumanResources.sol#L57-L75](contracts/internal/HumanResources.sol#L57-L75)
- [EmployeeBadge.sol#L88-L99](contracts/internal/tokens/EmployeeBadge.sol#L88-L99)
- [AdminBadge.sol#L47-L55](contracts/internal/tokens/AdminBadge.sol#L47-L55)

#### Client Acquisition
```
User → payForAccess() 
     → Payment transferred 
     → CLIENT_BADGE minted (no expiry)
     → Access granted to VPN nodes
```
Reference: [PaymentPool.sol#L125-L131](contracts/product/PaymentPool.sol#L125-L131)

#### Validator Onboarding
```
Admin → mintValidatorBadge(address, stakingAmount) 
     → ValidatorInfo stored with staking details 
     → Can now validate OPERATOR_ROLE applicants 
     → BURNER_ROLE can revoke
```
Reference: [ValidatorToken.sol#L47-L64](contracts/product/tokens/ValidatorToken.sol#L47-L64)

---

## TOKEN/BADGE TRANSFER AND REVOCATION SUMMARY

| Persona | Transferable? | Revocation Mechanism | Revoked By | Expiry |
|---------|---------------|---------------------|-----------|--------|
| ADMIN_BADGE | No (Soulbound) | burnAdminBadge() | DEFAULT_ADMIN_ROLE | None |
| CLIENT_ROLE | No (Soulbound) | burn() | BURNER_ROLE | Optional (per token) |
| OPERATOR_ROLE | No (Soulbound) | deregisterOperator() | BURNER_ROLE | None (marked inactive) |
| VALIDATOR_ROLE | No (Soulbound) | revokeValidatorBadge() | BURNER_ROLE | None |
| BUILDER_ROLE | No (Soulbound) | Admin action | DEFAULT_ADMIN_ROLE | None |
| EMPLOYEE_BADGE | No (Soulbound) | burnExpiredBadges() | DEFAULT_ADMIN_ROLE | 52 weeks (default) |
| BETA_TESTER_BADGE | No (Soulbound) | burn() | BURNER_ROLE | Optional (per token) |
| PROJECT_SPONSOR_BADGE | No (Soulbound) | Admin action | DEFAULT_ADMIN_ROLE | 52 weeks (fixed) |

---

## KEY SECURITY OBSERVATIONS

### Access Control Patterns

1. **Soulbound Enforcement**: All tokens/badges use `_beforeTokenTransfer()` to enforce soulbound semantics
   - Blocks transfers except for mint/burn
   - Examples: [AdminBadge.sol#L68-L76](contracts/internal/tokens/AdminBadge.sol#L68-L76), [ClientToken.sol#L96-L104](contracts/product/tokens/ClientToken.sol#L96-L104)

2. **Role-Based Minting**: All minting is gated by roles
   - MINTER_ROLE or DEFAULT_ADMIN_ROLE required
   - Prevents unauthorized token creation

3. **Prerequisite Checks**: Several operations require possession of other tokens
   - AdminBadge requires BuilderToken: [AdminBadge.sol#L44](contracts/internal/tokens/AdminBadge.sol#L44)
   - EmployeeBadge requires BuilderToken: [EmployeeBadge.sol#L81-L86](contracts/internal/tokens/EmployeeBadge.sol#L81-L86)
   - AnnualizedBadges requires BuilderToken: [AnnualizedBadges.sol#L52](contracts/internal/tokens/AnnualizedBadges.sol#L52)

4. **Expiry Management**: Critical for temp badges
   - Uses `ExpiryManagement` library
   - Default 52 weeks for employee and sponsor badges
   - Optional for client/beta tester badges

5. **Operator Validation Pipeline**: Two-step approval process
   - Apply → Validator approval → Activated
   - Prevents rogue operators: [SkypierVPN.sol#L92-L107](contracts/product/SkypierVPN.sol#L92-L107)

---

## CONTRACT INTERACTION DIAGRAM

```
PaymentPool (orchestrator)
├── Uses: ClientToken, SkypierToken
├── Tracks: Operators, Validators, Builders
├── Requires: BUILDER_ROLE, PAYMENT_MANAGER
└── Distributes: Network payments, Builder payments

SkypierVPN (operator lifecycle)
├── Uses: SkypierBadges, SkypierToken
├── Manages: Node registration, Operator validation
├── Requires: VALIDATOR_ROLE, ADMIN_ROLE
└── Calls: ValidatorToken.mintValidatorBadge()

HumanResources (builder management)
├── Tracks: Builder allocations, payments
├── Requires: HR_MANAGER_ROLE, TREASURER_ROLE
├── Related: BuilderToken, EmployeeBadge
└── Calls: registerBuilder(), processPayment()

Token Contracts (ERC1155 soulbound)
├── AdminBadge: Requires BUILDER_BADGE prerequisite
├── EmployeeBadge: Requires BUILDER_BADGE prerequisite
├── AnnualizedBadges: Requires BUILDER_BADGE prerequisite
├── InvestorToken: Independent tracking
├── ValidatorToken: Staking metadata
├── OperatorToken: Node metadata
└── ClientToken: Payment-driven
```

---

## INITIALIZATION CHECKLIST FOR COMPLETE SYSTEM

1. **Deploy Core Infrastructur**
   - BuilderToken
   - AdminBadge (needs BuilderToken address)
   - BaseAccessControlledUpgradeableToken (base)

2. **Deploy Token Contracts**
   - SkypierToken
   - ClientToken (MINTER_ROLE, BURNER_ROLE)
   - OperatorToken (MINTER_ROLE, BURNER_ROLE)
   - ValidatorToken (MINTER_ROLE, BURNER_ROLE)

3. **Deploy Badge Contracts**
   - SkypierBadges (with MINTER_ROLE)
   - EmployeeBadge (requires BuilderToken)
   - AnnualizedBadges (requires BuilderToken)
   - InvestorToken
   - ProjectSponsorBadge

4. **Deploy Operational Contracts**
   - SkypierVPN (with badges, token, payment pool addresses)
   - PaymentPool (with all token addresses)
   - HumanResources (with builder wallet)

5. **Grant Roles**
   - MINTER_ROLE to PaymentPool for ClientToken
   - MINTER_ROLE to SkypierVPN for SkypierBadges
   - HR_MANAGER_ROLE/TREASURER_ROLE in HumanResources
   - PAYMENT_MANAGER in PaymentPool

---

## REFERENCES

- Role definitions: [Roles.sol](contracts/lib/Roles.sol)
- Payment orchestration: [PaymentPool.sol](contracts/product/PaymentPool.sol)
- VPN core: [SkypierVPN.sol](contracts/product/SkypierVPN.sol)
- Builder management: [HumanResources.sol](contracts/internal/HumanResources.sol)
- Base access control: [BaseAccessControlledUpgradeableToken.sol](contracts/lib/BaseAccessControlledUpgradeableToken.sol)
