# Skypier Smart Contract - Persona Quick Reference Guide

**For developers, auditors, and operators**  
**Quick lookup for persona workflows, functions, and dependencies**

---

## Quick Persona Summary Table

| Persona | ID | Duration | Prerequisites | Key Function | Access Control |
|---------|----|----|---|---|---|
| **CLIENT** | 0 | Variable (default 30d) | ETH/USDC payment | `PaymentPool.deposit()` → VPN | Public (payment-gated) |
| **OPERATOR** | 2 | Indefinite | VALIDATOR approval | `SkypierVPN.applyAsOperator()` | Public (validator-gated) |
| **VALIDATOR** | 3 | Indefinite | Staking capital | `ValidatorToken.mintValidatorBadge()` | MINTER_ROLE |
| **BUILDER** | 4 | Indefinite | Admin grant | `BuilderToken.mintBuilderToken()` | DEFAULT_ADMIN_ROLE |
| **EMPLOYEE** | 5 | 52 weeks | BUILDER token holder | `EmployeeLevelBadge.mintEmployeeLevelBadge()` | BUILDER + ADMIN |
| **ADMIN** | 0 | Indefinite | BUILDER + ADMIN | `AdminBadge.mintAdminBadge()` | BUILDER + ADMIN |
| **BETA_TESTER** | 6 | Optional | Minter discretion | `SkypierBadges.mintBadge()` | MINTER_ROLE |
| **PROJECT_SPONSOR** | 7 | 52 weeks | Admin grant | `ProjectSponsorBadge.mintSponsorBadge()` | DEFAULT_ADMIN_ROLE |

---

## Function Quick Reference by Persona

### CLIENT PERSONA Functions

```solidity
// Main Entry Point
PaymentPool.deposit()
├─ Access: PUBLIC
├─ Triggers: ClientToken.mint() [off-chain relayer]
├─ Input: {value: ETH >= paymentAmount}
└─ Returns: Implicit (via event)

// Status Check
ClientToken.balanceOf(address, CLIENT_BADGE) → uint256
├─ Access: PUBLIC VIEW
├─ Returns: 1 if active, 0 if revoked/never had
└─ Use: Gateway checks before allowing VPN connection

ClientToken.isExpired(tokenId) → bool
├─ Access: PUBLIC VIEW
├─ Returns: true if token expired
└─ Use: Combined with balanceOf for access control

// Revocation (Admin)
ClientToken.burn(from, CLIENT_BADGE, amount)
├─ Access: BURNER_ROLE
├─ Effect: balanceOf[from][0] = 0
└─ Event: BadgeRevoked(from, CLIENT_BADGE, amount)
```

---

### OPERATOR PERSONA Functions

```solidity
// Step 1: Apply
SkypierVPN.applyAsOperator(string memory peerId)
├─ Access: PUBLIC
├─ Requirements: !revokedOperators[msg.sender], !nodes[msg.sender].isActive
├─ Effect: Added to operatorWaitlist
└─ Event: OperatorAddedToWaitlist(msg.sender)

// Step 2: Wait for Validator
[Off-chain: Validator reviews application]

// Step 3: Validator Approves (CRITICAL GATE)
SkypierVPN.validateOperator(address operator, string memory peerId)
├─ Access: VALIDATOR_ROLE ONLY ⚠️
├─ Requirements: Operator on waitlist
├─ Effect: Mints OperatorToken, creates Node struct
└─ Event: OperatorValidated(operator, peerId)

// Ongoing: Heartbeat (Keep-Alive)
SkypierVPN.heartbeat(address operatorAddress)
├─ Access: PUBLIC (permissionless)
├─ Effect: updates lastHeartbeat timestamp
└─ Use: Prevent timeout revocation (off-chain policy)

// Status Check
nodes[address].isActive → bool
├─ Access: PUBLIC
├─ Returns: true if operator is active
└─ Use: Off-chain node management

// Revocation (Admin)
SkypierVPN.revokeOperator(address operator)
├─ Access: ADMIN_ROLE
├─ Effect: Sets revokedOperators[operator] = true
└─ Event: NodeRevoked(operator)
```

---

### VALIDATOR PERSONA Functions

```solidity
// Registration (MINTER grants initially)
ValidatorToken.mintValidatorBadge(address to, uint256 stakingAmount)
├─ Access: MINTER_ROLE
├─ Precondition: to != address(0), stakingAmount > 0
├─ Effect: Mints badge, grants VALIDATOR_ROLE
├─ Event: ValidatorRegistered(to, stakingAmount)
└─ Off-chain: Validator should have deposited stake first

// Main Responsibility: Approve Operators
SkypierVPN.validateOperator(address operator, string memory peerId)
├─ Access: VALIDATOR_ROLE ONLY
├─ Purpose: Transition operator from WAITLIST → ACTIVE
└─ Consequence: Only validator can activate operators [CRITICAL]

// Status Check
ValidatorToken.getValidatorInfo(address validator) → ValidatorInfo
├─ Access: PUBLIC VIEW
├─ Returns: {wallet, stakingAmount, registeredAt, isActive}
└─ Use: Verify validator status

validators[address].isActive → bool
├─ Access: PUBLIC
├─ Returns: true if validator active
└─ Use: Payment distribution filters

// Revocation (Admin)
ValidatorToken.revokeValidatorBadge(address from)
├─ Access: BURNER_ROLE
├─ Effect: Burns badge, revokes VALIDATOR_ROLE
├─ Consequence: Operator activation blocked until new validator
└─ Event: ValidatorDeregistered(from)
```

---

### BUILDER PERSONA Functions

```solidity
// Grant (ADMIN ONLY)
BuilderToken.mintBuilderToken(address to)
├─ Access: DEFAULT_ADMIN_ROLE
├─ Effect: Mints BUILDER_BADGE to address
└─ Impact: Enables employee/admin management

// Employee Management
EmployeeLevelBadge.mintEmployeeLevelBadge(
    address to, 
    uint256 amount, 
    uint256 customExpiryDuration
)
├─ Access: BUILDER token holder + DEFAULT_ADMIN_ROLE
├─ Preconditions: amount <= 6 (WALLET_CAP)
├─ Effect: Creates employee badge with expiry
├─ Expiry: customExpiryDuration or default 52 weeks
└─ Event: BadgeExpired(tokenId, expiryTime)

EmployeeLevelBadge.extendExpiry(uint256 tokenId, uint256 additionalDuration)
├─ Access: DEFAULT_ADMIN_ROLE
├─ Effect: Extends badge expiry
└─ Use: Before badge expires (renewal before termination)

// Admin Delegation
AdminBadge.mintAdminBadge(address to)
├─ Access: BUILDER token holder + DEFAULT_ADMIN_ROLE
├─ Effect: Creates new admin with ADMIN_BADGE + role
└─ Impact: New admin can delegate roles and manage system

// Parameter Management (via delegates)
PaymentPool functions (PAYMENT_MANAGER role):
├─ setPaymentAmount(uint256 newAmount)
├─ setWallets(address network, address builder, address developer)
└─ distributePayments()

HumanResources functions (HR_MANAGER_ROLE):
├─ registerBuilder(address, string role, uint256 allocation)
├─ updateBuilderAllocation(address, uint256 newAllocation)
└─ processPayment(address builder)
```

---

### EMPLOYEE_BADGE PERSONA Functions

```solidity
// Creation (Builder)
EmployeeLevelBadge.mintEmployeeLevelBadge(to, amount, duration)
├─ By: BUILDER token holder + admin
├─ Effect: Minted with expiry = block.timestamp + duration
└─ Duration: Default 52 weeks if duration = 0

// Verification
EmployeeLevelBadge.hasBadge(address holder, uint256 tokenId) → bool
├─ Access: PUBLIC VIEW
├─ Returns: true if holder has badge
└─ Use: Off-chain: Check benefits eligibility

EmployeeLevelBadge.isExpired(uint256 tokenId) → bool
├─ Access: PUBLIC VIEW
├─ Returns: true if badge past expiry date
└─ Use: Combined with hasBadge() for access control

EmployeeLevelBadge.getBadgeExpiry(uint256 tokenId) → uint256
├─ Access: PUBLIC VIEW  
├─ Returns: Absolute timestamp when badge expires
└─ Use: Calculate time remaining

// Renewal
EmployeeLevelBadge.extendExpiry(uint256 tokenId, uint256 additionalDuration)
├─ By: Admin
├─ Effect: expiryTime += additionalDuration
└─ Use: Extend before termination or on renewal

// Termination/Expiration
EmployeeLevelBadge.burnExpiredBadges(address from, uint256 tokenId)
├─ By: Admin
├─ Precondition: isExpired(tokenId) must be true (or force burn)
├─ Effect: Destroys badge, employee loses benefits
└─ Event: Badge burned

// Automatic Expiry Checking
ExpiryManagement.isExpired() ← Called by burnExpiredBadges()
ExpiryManagement.getTimeRemaining() ← Off-chain use for alerts
```

---

### ADMIN_BADGE PERSONA Functions

```solidity
// Promotion (BUILDER grants)
AdminBadge.mintAdminBadge(address to)
├─ By: BUILDER token holder + existing admin
├─ Effect: 
│  ├─ Mints ADMIN_BADGE token
│  └─ Grants DEFAULT_ADMIN_ROLE
└─ Impact: New admin has full system control

// System-Wide Control
AccessControl.grantRole(bytes32 role, address account)
├─ By: ADMIN_ROLE
├─ Grantable roles: MINTER, BURNER, PAUSER, HR_MANAGER, PAYMENT_MANAGER, etc.
└─ Use: Delegate specific responsibilities

AccessControl.revokeRole(bytes32 role, address account)
├─ By: ADMIN_ROLE
├─ Effect: Removes role from account
└─ Use: Immediate access removal

// Token Lifecycle Control
[Any token contract].pause()
├─ By: PAUSER_ROLE (delegated by admin)
├─ Effect: All mint/transfer operations blocked
└─ Use: Emergency freeze

[Any token contract].unpause()
├─ By: PAUSER_ROLE
├─ Effect: Resume all operations
└─ Use: Resume after emergency

// Parameter Configuration
PaymentPool.setPaymentAmount(uint256 newAmount)
├─ By: PAYMENT_MANAGER
├─ Effect: Changes required ETH for CLIENT_BADGE
└─ Use: Adjust pricing

PaymentPool.setWallets(address network, address builder, address developer)
├─ By: ADMIN
├─ Effect: Configures payment distribution destinations
└─ Use: Change fund allocation pools

// Contract Upgrades
[Upgradeable].upgradeToAndCall(address newImplementation, bytes calldata data)
├─ By: ADMIN (via _authorizeUpgrade)
├─ Effect: Upgrades proxy to new implementation
└─ Use: Deploy new contract features

// Comprehensive Revocation
AdminBadge.burnAdminBadge(address from, uint256 tokenId)
├─ By: ADMIN_ROLE
├─ Effect: 
│  ├─ Burns ADMIN_BADGE token
│  └─ Revokes DEFAULT_ADMIN_ROLE
└─ Consequence: Complete admin removal
```

---

### BETA_TESTER_BADGE PERSONA Functions

```solidity
// Issuance
SkypierBadges.mintBadge(address to, uint256 badgeId, uint256 amount, bytes data)
├─ Access: MINTER_ROLE
├─ Parameters:
│  ├─ badgeId: 6 (BETA_TESTER_BADGE_ID)
│  ├─ amount: Typically 1
│  └─ data: Optional metadata
├─ Effect: Mints badge, stores BadgeAttributes
└─ Event: BadgeMinted(to, tokenId, amount)

// Status Verification
SkypierBadges.balanceOf(address account, uint256 tokenId) → uint256
├─ Access: PUBLIC VIEW
├─ Returns: 1 if beta tester, 0 otherwise
└─ Use: Gateway check for early feature access

SkypierBadges.getBadgeAttributes(uint256 badgeId, address holder)
├─ Access: PUBLIC VIEW
├─ Returns: BadgeAttributes {holder, issuer, issuedAt, expiresAt}
└─ Use: Query badge metadata

// Revocation
SkypierBadges.revokeBadge(address from, uint256 badgeId)
├─ Access: MINTER_ROLE
├─ Effect: Burns badge, clears attributes
└─ Use: End beta testing phase or upgrade to paid

// Transition Path
ClientToken.mint(betaTester, CLIENT_BADGE, 1, metadata)
├─ After: Successful beta phase
├─ Effect: Upgrade beta tester to paying client
└─ Optional: Revoke beta badge after promotion
```

---

### PROJECT_SPONSOR_BADGE PERSONA Functions

```solidity
// Issuance
ProjectSponsorBadge.mintSponsorBadge(
    address to, 
    string memory projectId, 
    uint256 duration
)
├─ Access: DEFAULT_ADMIN_ROLE ONLY
├─ Parameters:
│  ├─ to: Sponsor address
│  ├─ projectId: Project identifier (e.g., "Q2_EXPANSION")
│  └─ duration: Project length (0 = default 52 weeks)
├─ Effect: Creates unique badge with project tracking
├─ Expiry: Automatic 52 weeks from issuance
└─ Event: BadgeMinted(tokenId, projectId, sponsor, expiry)

// Project Information Retrieval
ProjectSponsorBadge.getProjectInfo(uint256 tokenId) → ProjectInfo
├─ Access: PUBLIC VIEW
├─ Returns: {projectId, startTime, endTime, sponsor}
├─ Use: Display project timeline and sponsor info
└─ Off-chain: Build sponsor dashboard

// Badge Validity Check
ProjectSponsorBadge.isValidBadge(uint256 tokenId) → bool
├─ Access: PUBLIC VIEW
├─ Returns: true if badge not expired
③─ Logic: (block.timestamp < endTime && isActive)
└─ Use: Conditional sponsor benefits

ProjectSponsorBadge.balanceOf(address sponsor, uint256 tokenId) → uint256
├─ Access: PUBLIC VIEW
├─ Returns: 1 if sponsor active, 0 if burned/never had
└─ Use: Verify current sponsorship status

// Status Monitoring
ExpiryManagement.getTimeRemaining() → uint256
├─ Returns: seconds until badge expires (0 if expired)
└─ Use: Off-chain alerts for renewal

// Project Completion (Automatic)
[After endTime passed]
├─ Badge remains in wallet (soulbound, cannot burn)
├─ isValidBadge() returns false
├─ Off-chain: Archive as historical record
└─ Use: Historical project tracking

// Manual Termination (If Implemented)
[Future function: revokeSponsorBadge()]
├─ Would allow early project termination
├─ Similar to burnAdminBadge()
└─ Currently not in implementation
```

---

## Critical Operations Checklist

### System Initialization

```
□ Deploy contracts in dependency order:
  □ BuilderToken
  □ ValidatorToken  
  □ OperatorToken
  □ ClientToken
  □ SkypierVPN
  □ PaymentPool
  □ EmployeeLevelBadge
  □ AdminBadge
  □ ProjectSponsorBadge
  □ SkypierBadges
  □ HumanResources

□ Initialize contracts:
  □ BuilderToken.initialize()
  □ ValidatorToken.initialize()
  □ [... all others ...]

□ Bootstrap minimum viable state:
  □ ValidatorToken.mintValidatorBadge(validator, stake)
     ⚠️ CRITICAL: Must have at least 1 validator
  □ BuilderToken.mintBuilderToken(builder)
  □ AdminBadge.mintAdminBadge(admin)
  □ PaymentPool.setPaymentAmount(amount)
  □ PaymentPool.setWallets(network, builder, developer)

□ System status checks:
  □ Verify VALIDATOR_ROLE exists
  □ Verify ADMIN_ROLE exists
  □ Verify BUILDER_ROLE exists
  □ Verify PaymentPool configured
```

### Adding First Client

```
□ Client deposits:
  □ Client calls PaymentPool.deposit() with ETH
  □ VERIFY: msg.value >= paymentAmount

□ Mint badge:
  □ Relayer calls ClientToken.mint(client, 0, 1, metadata)
  □ VERIFY: MINTER_ROLE granted to relayer

□ Verify access:
  □ Check: balanceOf(client, 0) == 1
  □ Check: !isExpired(tokenId)
  □ Result: VPN access granted ✓
```

### Adding First Operator

```
□ Operator applies:
  □ Operator calls SkypierVPN.applyAsOperator(peerId)
  □ VERIFY: !revokedOperators[operator]
  □ VERIFY: operator added to waitlist

□ Validator approves:
  □ Validator calls SkypierVPN.validateOperator(operator, peerId)
  ⚠️ VERIFY: Caller has VALIDATOR_ROLE
  □ VERIFY: Operator was on waitlist

□ Verify activation:
  □ Check: nodes[operator].isActive == true
  □ Check: balanceOf(operator, tokenId) == 1
  □ Result: Operator can run node ✓
```

### Adding First Employee

```
□ Builder creates badge:
  □ Builder calls EmployeeLevelBadge.mintEmployeeLevelBadge(employee, 1, 0)
  □ VERIFY: Builder has BUILDER_BADGE
  □ VERIFY: Caller has ADMIN_ROLE

□ Verify expiry:
  □ Check: getBadgeExpiry(tokenId) == block.timestamp + 52 weeks
  □ Check: !isExpired(tokenId) == true

□ Verify benefits:
  □ Check: hasBadge(employee, tokenId) == true
  □ Result: Employee receives benefits for 52 weeks ✓

□ Before expiry:
  □ Admin can: extendExpiry(tokenId, 52 weeks) [renewal]
  □ Admin can: mint new badge [fresh badge]
  □ Admin can: wait for auto-expiry then burnExpiredBadges()
```

---

## Common Patterns & Idioms

### Access Control Pattern

```solidity
// 1. Single Role
function onlyBuilderTokenHolder() {
    require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token");
}

// 2. Dual Requirements (Role + Token)
function onlyBuilderAndAdmin() {
    require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0);
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
}

// 3. AccessControl Modifier
modifier onlyRole(bytes32 role) {
    require(hasRole(role, msg.sender), "Access Denied");
    _;
}

// 4. Soulbound Enforcement
function _beforeTokenTransfer(address from, address to, ...) {
    require(from == address(0) || to == address(0), "Token is soulbound");
}
```

### Expiry Management Pattern

```solidity
// Set relative expiry
expiry.setExpiry(52 weeks) // Now + 52 weeks

// Set absolute expiry
expiry.setExpiryAbsolute(uint64(1735689600)) // Jan 1, 2025

// Check status
if (expiry.isExpired()) { /* revoke benefits */ }
if (expiry.isValid()) { /* grant benefits */ }

// Get time left
uint256 timeLeft = expiry.getTimeRemaining(); // 0 if expired

// Extend before expiry
expiry.extendExpiry(52 weeks); // Add more time
```

### Payment Distribution Pattern

```solidity
// Bi-weekly distribution check
if (block.timestamp >= lastDistributionTime + BIOWEEKLY_INTERVAL) {
    for (address operator : operators) {
        if (operators[operator].isActive) {
            uint256 share = totalPool / activeCount;
            transfer(operators[operator].wallet, share);
            operators[operator].lastPayment = block.timestamp;
        }
    }
    lastDistributionTime = block.timestamp;
}
```

### Role Delegation Pattern

```solidity
// Admin delegates minting
function delegateMinting(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(MINTER_ROLE, minter);
    emit RoleDelegated(minter, MINTER_ROLE);
}

// Sub-role revocation
function revokeMinting(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(MINTER_ROLE, minter);
    emit RoleRevoked(minter, MINTER_ROLE);
}
```

---

## Troubleshooting Guide

### "Operator cannot activate"

**Symptom:** `applyAsOperator()` succeeds, but `validateOperator()` cannot be called

**Cause:** No VALIDATOR exists or VALIDATOR_ROLE revoked

**Solution:**
```solidity
// Check if validator exists
ValidatorInfo memory info = ValidatorToken.getValidatorInfo(validatorAddress);
if (!info.isActive) {
    // Validator inactive - must reactivate or add new validator
    ValidatorToken.mintValidatorBadge(newValidator, stakingAmount);
}
```

---

### "Employee badge won't mint"

**Symptom:** `mintEmployeeLevelBadge()` reverts

**Possible Causes:**
```
1. Caller doesn't have BUILDER_BADGE
   → Check: balanceOf(caller, BUILDER_BADGE) == 1
   
2. Caller doesn't have ADMIN_ROLE
   → Check: hasRole(DEFAULT_ADMIN_ROLE, caller)
   
3. Amount exceeds WALLET_CAP (6)
   → Check: amount <= 6
   
4. Employee address is zero
   → Check: to != address(0)
```

---

### "Payment distribution failing"

**Symptom:** `distributePayments()` doesn't execute

**Possible Cause:**
```solidity
// Check timing
if (block.timestamp < lastDistributionTime + BIOWEEKLY_INTERVAL) {
    // Too early - wait 14 days from last distribution
    uint256 timeToWait = lastDistributionTime + BIOWEEKLY_INTERVAL - block.timestamp;
    // Revert with: "Distribution runs every 14 days only"
}
```

---

### "Operator can't be approved"

**Symptom:** `validateOperator()` reverts with "onlyRole"

**Cause:** Caller lacks VALIDATOR_ROLE

**Solution:**
```solidity
// Check: Does caller have VALIDATOR_BADGE?
ValidatorInfo memory info = ValidatorToken.getValidatorInfo(msg.sender);
if (!info.isActive) {
    // Revert: "Caller must have VALIDATOR_ROLE"
    // Only validators can approve operators
}
```

---

## Performance & Gas Considerations

| Operation | Gas Estimate | Frequency | Notes |
|-----------|---|---|---|
| PaymentPool.deposit() | ~50K | Per client | Payment triggers minting |
| SkypierVPN.applyAsOperator() | ~40K | Per operator | Just adds to waitlist |
| SkypierVPN.validateOperator() | ~150K | Per validator approval | Critical: mints token |
| ClientToken.mint() | ~80K | Per client deposit | ERC1155 mint operation |
| EmployeeLevelBadge.mint() | ~120K | Per employee grant | Includes expiry setup |
| PaymentPool.distributePayments() | ~500K+ | Bi-weekly | Loops through all participants |
| AdminBadge.mintAdminBadge() | ~140K | Rare | Role + token grant |

**Optimization Tips:**
- Batch distributePayments() calls per 50-100 participants
- Use off-chain indexing for queries
- Aggregate operator heartbeats (not on-chain)

---

## Security Checklist

- [ ] VALIDATOR_ROLE exists and held by trusted party (minimum 1)
- [ ] ADMIN_ROLE not compromised (multi-sig recommended)
- [ ] BUILDER_ROLE distributed among core team (minimum 1)
- [ ] All soulbound tokens enforced via `_beforeTokenTransfer()`
- [ ] Emergency pause enabled (PAUSER_ROLE assigned)
- [ ] PaymentPool configured with correct wallets
- [ ] ExpiryManagement integrated for all time-based roles
- [ ] No revoked operators have node access
- [ ] bi-weekly distribution running (monitored)
- [ ] Operator heartbeat mechanism operational
- [ ] Bootstrap admin not compromised

---

**Last Updated:** April 13, 2026  
**Document Series:** PERSONA_FUNCTION_FLOW.md | PERSONA_VISUAL_DIAGRAMS.md | PERSONA_QUICK_REFERENCE.md
