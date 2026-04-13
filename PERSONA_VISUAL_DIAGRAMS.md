# Skypier Smart Contract - Visual Persona Flow Diagrams

**Companion to:** PERSONA_FUNCTION_FLOW.md  
**Contains:** Mermaid diagrams and visual representations

---

## General Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     SKYPIER ECOSYSTEM ARCHITECTURE                              │
└─────────────────────────────────────────────────────────────────────────────────┘

                                   ┌─────────────────┐
                                   │   ADMIN_BADGE   │ (Top Authority)
                                   │  DEFAULT_ADMIN  │
                                   └────────┬────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    │                       │                       │
                    ↓                       ↓                       ↓
            ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
            │ BUILDER_TOKEN│       │ MINTER_ROLE  │       │  PAUSE_ROLE  │
            │  BADGE (0)   │       │ (sub-roles)  │       │  (emergency) │
            └──────┬───────┘       └──────┬───────┘       └──────────────┘
                   │                      │
        ┌──────────┼──────────┐            │
        ↓          ↓          ↓            │
    EMPLOYEE   ADMIN_BADGE  BUILDER       │
    _BADGE      (cascades)   PERMISSIONS  │
                                          │
                    ┌─────────────────────┘
                    │
    ┌───────────────┼──────────────┬──────────────┬───────────────┐
    │               │              │              │               │
    ↓               ↓              ↓              ↓               ↓
┌────────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐ ┌─────────────┐
│  CLIENT    │ │OPERATOR  │ │VALIDATOR │ │ BETA_TESTER   │ │PROJECT_    │
│   ROLE     │ │  ROLE    │ │  ROLE    │ │   BADGE       │ │SPONSOR_BAD │
│            │ │          │ │          │ │               │ │    GE       │
│ Payment:   │ │ App:     │ │Validator:│ │ Admin:        │ │ Admin:      │
│ ETH/USDC   │ │ Node     │ │ Approve  │ │ TestFeatures  │ │ Projects,   │
│            │ │ Provision│ │ Operators│ │               │ │ Sponsors    │
└──────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┬───────┘ └──────┬──────┘
       │            │            │                │                │
       │            │            │ CRITICAL GATE  │                │
       │            │            ↓ (Dependency)   │                │
       │            └────────→ validateOperator() │                │
       │                       [VALIDATOR_ONLY]   │                │
       │                                          │                │
       └──────────────────────────────────────────┴────────────────┘
                              ↓
                        PaymentPool
                    (Distributes rewards)
                    ├─ Bi-weekly to ops
                    ├─ Bi-weekly to validators
                    └─ Monthly to builders (via HR)
```

---

## Persona State Transitions

```
┌────────────────────────────────────────────────────────────────┐
│            CLIENT PERSONA - STATE TRANSITIONS                   │
└────────────────────────────────────────────────────────────────┘

        ┌─────────────────────────────────────────────────────┐
        │                                                    │
        │  [NO_ACCESS]                                      │
        │  (Wallet has no CLIENT_BADGE)                     │
        │                                                    │
        └────┬────────────────────────────────────────────────┘
             │
             │ PaymentPool.deposit() + ClientToken.mint()
             │
             ↓
        ┌──────────────────────────────────────────────────┐
        │  [ACTIVE_CLIENT] - Duration: T₀ to T₀ + 30d     │
        │  ├─ balanceOf[client][0] = 1                    │
        │  ├─ !isExpired() = true                         │
        │  └─ VPN Access: ALLOWED                         │
        └──────┬───────────────────────────────────────────┘
               │ 
         ┌─────┴──────┬────────────┐
         │            │            │
         │ After T₀+30d Renew (new deposit)
         ↓            ↓            │
    [EXPIRED]    [ACTIVE]         │
    ├─ burn()      loop ←──────────┘
    ├─ access:DENIED
    └─→ REACTIVATE (new token)

│────────────────────────────────────────────────────────────────│
│            OPERATOR PERSONA - STATE TRANSITIONS                 │
│────────────────────────────────────────────────────────────────│

    ┌──────────────────────────────────────┐
    │  [FRESH_USER]                        │
    │  (No application)                    │
    └────┬─────────────────────────────────┘
         │
         │ applyAsOperator(peerId)
         │
         ↓
    ┌──────────────────────────────────────────────────────┐
    │  [WAITING_VALIDATION]                                │
    │  ├─ operatorWaitlist[i] = operator                   │
    │  ├─ operatorPeerIds[operator] = peerId              │
    │  └─ No node registration yet                         │
    └────┬────────────────────────────┬────────────────────┘
         │                            │
         │ validateOperator()         │ revokeOperator()
         │ [VALIDATOR_ONLY]           │ [ADMIN_ONLY]
         │ (Critical!)                │
         ↓                            ↓
    ┌──────────────────────────┐ ┌─────────────────────────┐
    │  [ACTIVE_OPERATOR]       │ │  [REVOKED_OPERATOR]    │
    │  ├─ nodes[op] created    │ │  ├─ revokedOperators[] │
    │  ├─ OperatorToken minted │ │  ├─ nodes.isActive=F   │
    │  ├─ isActive = true      │ │  └─ No future ops      │
    │  ├─ heartbeat tracking   │ │                        │
    │  ├─ Earning rewards      │ │                        │
    │  └─ VPN access: ALLOWED  │ │                        │
    └────┬────────────────────┘ └─────────────────────────┘
         │
         │ Periodic heartbeat
         │ (stays in ACTIVE)
         │
         ↓
    [INACTIVE - prolonged no-heartbeat]
         │
         │ Manual revocation
         └→ [REVOKED_OPERATOR]

│────────────────────────────────────────────────────────────────│
│            VALIDATOR PERSONA - STATE TRANSITIONS                │
│────────────────────────────────────────────────────────────────│

    ┌──────────────────────────────────┐
    │  [UNSTAKED_USER]                 │
    │  (Has capital, interested)       │
    └────┬─────────────────────────────┘
         │
         │ Deposit staking tokens
         │ mintValidatorBadge(address, stake)
         │
         ↓
    ┌──────────────────────────────────────────────┐
    │  [ACTIVE_VALIDATOR]                          │
    │  ├─ ValidatorToken minted (VALIDATOR_BADGE) │
    │  ├─ VALIDATOR_ROLE granted                  │
    │  ├─ validators[address].isActive = true     │
    │  ├─ Can call: validateOperator()            │
    │  ├─ Earning rewards (bi-weekly)             │
    │  └─ Status: OPERATIONAL ✓                   │
    └────┬──────────────────────────────────────────┘
         │
    ┌────┴──────────────────────────────────────┐
    │ Validates operators:                       │
    │ └→ SkypierVPN.validateOperator(op, peerID)│
    │    (This is critical authority)           │
    └────┬──────────────────────────────────────┘
         │
         │ revokeValidatorBadge() [Admin/Burner]
         │
         ↓
    ┌──────────────────────────────────┐
    │  [REVOKED_VALIDATOR]             │
    │  ├─ Badge burned                 │
    │  ├─ VALIDATOR_ROLE revoked       │
    │  ├─ Cannot validate operators    │
    │  └─ No future rewards            │
    └──────────────────────────────────┘

│────────────────────────────────────────────────────────────────│
│            EMPLOYEE_BADGE - STATE TRANSITIONS                   │
│────────────────────────────────────────────────────────────────│

    ┌─────────────────────────────────┐
    │  [NO_BADGE]                     │
    │  (New employee or terminated)   │
    └────┬────────────────────────────┘
         │
         │ mintEmployeeLevelBadge()
         │ [BUILDER + ADMIN required]
         │
         ↓
    ┌──────────────────────────────────────────────────┐
    │  [ACTIVE_EMPLOYEE] - Duration: T₀ + 52 weeks    │
    │  ├─ tokenId created (unique)                    │
    │  ├─ expiry = block.timestamp + 52 weeks         │
    │  ├─ isExpired() = false                         │
    │  ├─ Benefits: Voting, discounts, recognition   │
    │  └─ Status: ACTIVE ✓                           │
    └────┬───────┬──────────────┬──────────────────────┘
         │       │              │
    ┌────┴─┐ ┌───┴────────┐ ┌──┴──────────────┐
    │      │ │    After 52w │                 │
    │      │ │             │                 │
    │ Renew│ Expires   Manual (termination)
    │ (new │  │          │
    │ badge)│  ↓          ↓
    │  │   │ ┌──────────────────────┐
    └──┼─→ └→ [EXPIRED_BADGE]      │
       │      ├─ burnExpiredBadges()│
       │      ├─ No benefits        │
       │      └─ INACTIVE ✗         │
       │      └──────────────────────┘
       │
       └──→ [ACTIVE_EMPLOYEE] (re-badged)
```

---

## Dependency Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                 INITIALIZATION DEPENDENCY FLOW                          │
└────────────────────────────────────────────────────────────────────────┘

PHASE 1: CORE INFRASTRUCTURE
┌─────────────────────────────────────────────────────────────────┐
│ Deploy & Initialize:                                            │
├─────────────────────────────────────────────────────────────────┤
│ BuilderToken.sol                                               │
│   ├─ initialize()                                              │
│   ├─ _grantRole(DEFAULT_ADMIN_ROLE, deployer)                │
│   └─ Ready to mint: BuilderToken              ✓               │
│                                               │                │
│ ValidatorToken.sol                                             │
│   ├─ initialize()                                              │
│   ├─ _grantRole(MINTER_ROLE, deployer)                       │
│   └─ Ready to mint: ValidatorBadge            ✓               │
│                                               │                │
│ OperatorToken.sol                                              │
│   ├─ initialize()                                              │
│   ├─ _grantRole(MINTER_ROLE, skypierVpnAddress)              │
│   └─ Ready to mint: OperatorToken             ✓               │
│                                               │                │
│ ClientToken.sol                                                │
│   ├─ initialize(minter, admin)                                │
│   ├─ _grantRole(MINTER_ROLE, minter)                         │
│   └─ Ready to mint: ClientBadge               ✓               │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ↓
PHASE 2: ECOSYSTEM SETUP
┌─────────────────────────────────────────────────────────────────┐
│ PaymentPool <── Requires: ClientToken + ValidatorToken         │
│   ├─ initialize(clientToken, ...)                              │
│   ├─ Tracks: operators[], validators[], builders[]             │
│   ├─ DEPENDS ON: ClientToken to issue badges                  │
│   └─ DEPENDS ON: ValidatorToken state tracking                │
│                                                                │
│ SkypierVPN <── Requires: ValidatorToken + OperatorToken       │
│   ├─ initialize(badges, token, paymentPool, stake)            │
│   ├─ Stores: nodes[], revokedOperators[], operatorWaitlist[]│
│   ├─ DEPENDS ON: ValidatorToken for VALIDATOR_ROLE check    │
│   ├─ DEPENDS ON: OperatorToken to mint tokens               │
│   └─ CRITICAL GATE: validateOperator() [VALIDATOR_ONLY]     │
│                                                                │
│ EmployeeLevelBadge <── Requires: BuilderToken               │
│   ├─ initialize(builderToken, BUILDER_BADGE_ID, ...)        │
│   ├─ Modifier: onlyBuilderTokenHolder                        │
│   └─ DEPENDS ON: BuilderToken.balanceOf() for gating       │
│                                                                │
│ AdminBadge <── Requires: BuilderToken                        │
│   ├─ initialize(builderToken, BUILDER_BADGE_ID, ...)        │
│   └─ DEPENDS ON: BuilderToken.balanceOf() for gating       │
│                                                                │
│ HumanResources <── Requires: PaymentPool                     │
│   ├─ initialize(builderPoolWallet)                           │
│   ├─ Manages: builders[] (with monthly allocations)          │
│   └─ Uses: Network pool from PaymentPool                     │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ↓
PHASE 3: INITIAL ROLE BOOTSTRAP
┌─────────────────────────────────────────────────────────────────┐
│ Ensure minimum viable roles exist:                              │
├─────────────────────────────────────────────────────────────────┤
│ ✓ At least 1 VALIDATOR exists                                  │
│   (Critical: without validator, operators cannot activate)     │
│                                                                 │
│ ✓ At least 1 BUILDER exists                                    │
│   (Needed: to manage employees, create admins)                │
│                                                                 │
│ ✓ At least 1 ADMIN exists                                      │
│   (Given: at initialize(), but verify still present)           │
│                                                                 │
│ ✓ PaymentPool configured with:                                 │
│   - paymentAmount (ETH for client access)                      │
│   - Wallet addresses (network, builder, developer pool)        │
│   - ClientToken minter role assigned                           │
└─────────────────────────────────────────────────────────────────┘

KEY DEPENDENCY RULES:
• BuilderToken = prerequisite for EmployeeBadge & AdminBadge
• ValidatorToken = prerequisite for operator activation (critical!)
• PaymentPool = prerequisite for client badge minting
• SkypierVPN = prerequisite for operator management
• At least one validator must exist at all times
• Bootstrap admin role must not be empty
```

---

## Critical Path Diagram

```
┌────────────────────────────────────────────────────────────────┐
│         CRITICAL PATH: OPERATOR ACTIVATION                      │
│         (Single point of failure: VALIDATOR_ROLE)               │
└────────────────────────────────────────────────────────────────┘

TIMELINE: T₀ (Application) → T₁ (Validation) → T₂ (Active)

 ┌─────────────────────────────────────────────────────────────┐
 │  T₀: Operator Application Phase                             │
 └─────────────────────────────────────────────────────────────┘
    │
    ├─ Operator calls: applyAsOperator(peerId)
    │  └─ Preconditions:
    │     ├─ !revokedOperators[msg.sender] ✓ (can call if not revoked)
    │     └─ !nodes[msg.sender].isActive ✓ (can call if not already op)
    │
    ├─ State Change:
    │  ├─ operatorPeerIds[operator] = peerId
    │  └─ operatorWaitlist.push(operator)
    │
    └─ Event: OperatorAddedToWaitlist(operator)

 ┌─────────────────────────────────────────────────────────────┐
 │  T₁ (waiting): Validation Phase                             │
 └─────────────────────────────────────────────────────────────┘
    │
    ├─ System notifies validators (off-chain)
    │  └─ Validator reviews application
    │
    ├─ ⚠️ CRITICAL GATE: VALIDATOR MUST EXIST AND CALL validateOperator()
    │  │
    │  └─ If no validators exist:
    │     └─ validateOperator() CAN NEVER BE CALLED
    │        └─ Operator stuck in WAITLIST FOREVER
    │
    ├─ Validator calls: validateOperator(operator, peerId)
    │  │
    │  └─ Access Control: onlyRole(VALIDATOR_ROLE)
    │     └─ ONLY validator can execute this
    │        └─ If caller lacks VALIDATOR_ROLE → REVERTS
    │
    ├─ Preconditions checked:
    │  └─ require(bytes(operatorPeerIds[operator]).length > 0)
    │     └─ Operator must have called applyAsOperator() first
    │
    └─ Action: OperatorToken.mint(operator, peerId) → tokenId
       └─ Creates unique operator token with nodeId

 ┌─────────────────────────────────────────────────────────────┐
 │  T₂: Operator Active Phase                                  │
 └─────────────────────────────────────────────────────────────┘
    │
    ├─ State Change:
    │  ├─ nodes[operator] = Node {..., isActive: true}
    │  ├─ operatorInfo[tokenId] = OperatorInfo {...}
    │  └─ balanceOf[operator][tokenId] = 1
    │
    ├─ Operator can now:
    │  ├─ Run and manage VPN node
    │  ├─ Call heartbeat() to stay active
    │  ├─ Earn bi-weekly rewards from PaymentPool
    │  └─ Be included in operator metrics
    │
    └─ VPN Gateway checks:
       └─ balanceOf(operator, operatorToken) > 0 && !revoked
          └─ Node operation allowed ✓

FAILURE SCENARIOS:
┌────────────────────────────────────────────────────────────┐
│ Scenario 1: No Validator Exists                            │
├────────────────────────────────────────────────────────────┤
│ State: applyAsOperator() succeeds ✓                       │
│ BLOCKED: validateOperator() cannot be called              │
│ Result: Operator stuck in waitlist forever ✗              │
│ Recovery: Admin must mint ValidatorToken to someone       │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Scenario 2: Validator Compromise                           │
├────────────────────────────────────────────────────────────┤
│ Risk: Validator can approve malicious operators            │
│ Mitigation: Admin can revoke VALIDATOR_ROLE immediately  │
│ Recovery: Mint new ValidatorToken to trusted party       │
│ Action: revokeOperator() to remove bad operators         │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Scenario 3: Validator Offline                             │
├────────────────────────────────────────────────────────────┤
│ Impact: Operators cannot activate                          │
│ Mitigation: Have multiple validators (decentralization)  │
│ Recovery: Transfer VALIDATOR_ROLE to backup validator    │
└────────────────────────────────────────────────────────────┘
```

---

## Role Access Heatmap

```
┌────────────────────────────────────────────────────────────┐
│    FUNCTION ACCESS HEATMAP (RED=Restricted, GREEN=Open)    │
└────────────────────────────────────────────────────────────┘

Function                        Restriction Level    Calls By
─────────────────────────────────────────────────────────────
PaymentPool.deposit()                  🟢 PUBLIC         Client
  └─ Anyone can deposit ETH

PaymentPool.distributePayments()       🔴 ADMIN ONLY     Admin/Treasurer
  └─ Only admin can initiate rewards

SkypierVPN.applyAsOperator()           🟢 PUBLIC         Operator
  └─ Anyone can apply

SkypierVPN.validateOperator()          🔴 VALIDATOR-ONLY Validator
  └─ SINGLE GATE: Only validator can approve

SkypierVPN.revokeOperator()            🔴 ADMIN ONLY     Admin
  └─ Only admin can revoke

ValidatorToken.mintValidator()         🔴 MINTER-ONLY    Admin (delegated)
  └─ Admin must grant minter role

ClientToken.mint()                     🔴 MINTER-ONLY    Admin (delegated)
  └─ Admin must grant minter role

EmployeeLevelBadge.mintEmployee()      🔴 BUILDER+ADMIN  Builder/Admin
  └─ Requires BOTH BUILDER token AND ADMIN role

AdminBadge.mintAdmin()                 🔴 BUILDER+ADMIN  Builder/Admin
  └─ Requires BOTH BUILDER token AND ADMIN role

ProjectSponsorBadge.mintSponsor()      🔴 ADMIN ONLY     Admin
  └─ Only admin can create sponsor badges

SkypierBadges.mintBadge()              🔴 MINTER-ONLY    Admin (delegated)
  └─ Admin must grant minter role


SECURITY TIERS:
🟢 PUBLIC (Tier 1) - No restrictions
   └─ Risk: Low (application validation only)
   
🟡 ROLE-BASED (Tier 2) - Requires specific role
   └─ Risk: Medium (role holder compromise = impact)
   
🔴 MULTI-GATE (Tier 3) - Requires BOTH token AND role
   └─ Risk: Low (redundant checks)
   
🔴🔴 CRITICAL (Tier 4) - Single authority with cascading impact
   └─ Risk: HIGH (validator compromise = operators stuck)
```

---

## Time & Expiry Management

```
┌────────────────────────────────────────────────────────────┐
│               TOKEN EXPIRY TIMELINE MANAGEMENT              │
└────────────────────────────────────────────────────────────┘

CLIENT_BADGE:
    T₀ (Deposit)  ── T₀ + 30d ── [EXPIRED]
    │              │             │
    └─ balanceOf=1 │ balanceOf=1 └─→ burn() → balanceOf=0
      isExpired=F  │ isExpired=T    (VPN access denied)
      access=YES   └─→ Gateway denies new connections

EMPLOYEE_BADGE:
    T₀ (Minted)   ── T₀ + 52w ── [EXPIRED]
    │              │             │
    └─ balanceOf=1 │ balanceOf=1 └─→ burnExpiredBadges() → balanceOf=0
      isExpired=F  │ isExpired=T    (benefits revoked)
      benefits=YES └─→ Can extend before expiry

PROJECT_SPONSOR_BADGE:
    T₀ (Minted)   ── T₀ + 52w ── [EXPIRED]
    │              │             │
    └─ balanceOf=1 │ balanceOf=1 └─→ Logo grayed out, archived
      isValidBadge │ isValidBadge=F  (project complete)
      =T           └─→ Project still queryable for history

OPERATOR_TOKEN:
    T₀ (Validated)  ... [ACTIVE INDEFINITELY]
    │
    └─ balanceOf=1
      isActive=T
      Earning=YES
      
    (No automatic expiry - manual revocation only)

VALIDATOR_TOKEN:
    T₀ (Staked)  ... [ACTIVE INDEFINITELY]
    │
    └─ balanceOf=1
      isActive=T
      VALIDATOR_ROLE=GRANTED
      
    (No automatic expiry - manual revocation only)

BUILDER_TOKEN:
    T₀ (Granted)  ... [ACTIVE INDEFINITELY]
    │
    └─ balanceOf=1
      Can create: Employees, Admins, BUILDER_BADGEs
      
    (No automatic expiry - manual revocation only)

ADMIN_BADGE:
    T₀ (Granted)  ... [ACTIVE INDEFINITELY]
    │
    └─ balanceOf=1
      DEFAULT_ADMIN_ROLE=GRANTED
      Can: Revoke all roles, upgrade contracts
      
    (No automatic expiry - manual revocation only)


EXPIRY LIBRARY METHODS:
┌────────────────────────────────────────────────────────────┐
│ setExpiry(duration)                                        │
│   └─ expiryTime = block.timestamp + duration              │
│      isActive = true                                       │
│                                                            │
│ setExpiryAbsolute(timestamp)                              │
│   └─ expiryTime = timestamp (fixed absolute time)        │
│      isActive = true                                       │
│                                                            │
│ isExpired() → bool                                         │
│   └─ return (block.timestamp >= expiryTime && isActive)  │
│                                                            │
│ isValid() → bool                                           │
│   └─ return (block.timestamp < expiryTime && isActive)   │
│                                                            │
│ extendExpiry(additionalDuration)                          │
│   └─ expiryTime += additionalDuration                    │
│                                                            │
│ getTimeRemaining() → uint256                             │
│   └─ return max(0, expiryTime - block.timestamp)        │
│                                                            │
│ revokeExpiry()                                            │
│   └─ isActive = false (permanent, cannot renew)          │
└────────────────────────────────────────────────────────────┘
```

---

## Cross-Persona Dependencies Matrix

```
┌────────────────────────────────────────────────────────────────────────────┐
│              PERSONA INTEROPERABILITY DEPENDENCY MATRIX                      │
└────────────────────────────────────────────────────────────────────────────┘

                CLIENT  OPERATOR  VALIDATOR  BUILDER  EMPLOYEE  ADMIN  BETA  SPONSOR
                ──────  ────────  ─────────  ───────  ────────  ─────  ────  ───────

Depends on:
CLIENT          -       -         -          -        -         [A]    -     -
OPERATOR        [P]     [V]       [V]        -        -         [A]    -     -
VALIDATOR       -       -         -          -        -         [A]    -     -
BUILDER         -       -         -          [A]      [B]       [B]    -     -
EMPLOYEE        -       -         -          [B]      -         [A]    -     -
ADMIN           -       [V2]      [V3]       [B]      [A]       -      -     [A]
BETA_TESTER     -       -         -          -        -         [A]    -     -
SPONSOR         -       -         -          -        -         [A]    -     -

LEGEND:
[A] = Admin approval required
[B] = Builder token holder required
[P] = Payment deposit required
[V] = Validator approval required (for operator activation)
[V2]= Not activation-critical but validator can report misbehavior
[V3]= Validator reports could trigger admin revocation
-   = No direct dependency

CRITICAL FLOWS:
├─ OPERATOR → [V=VALIDATOR] → Activation (single gate)
├─ BUILDER → [A=ADMIN] → Can exist (recursive but bootstrapped)
├─ EMPLOYEE → [B=BUILDER] → Requires builder token at mint time
├─ ADMIN → [B=BUILDER] → Requires builder token to be minted
└─ All → [A=ADMIN] → Admin override can revoke anyone


RISK ASSESSMENT:
┌─────────────────────────────────────────────────────────────┐
│ Critical Dependency (SINGLE POINT OF FAILURE):              │
│ └─ VALIDATOR_ROLE required for operator activation         │
│    └─ If all validators revoked → operators cannot activate │
│    └─ Mitigation: Keep ≥1 validator at all times           │
│                                                              │
│ High Import Dependency:                                     │
│ └─ BUILDER_ROLE required for employee management            │
│    └─ If all builders revoked → no new employees             │
│    └─ Mitigation: Distributed builder grants                │
│                                                              │
│ High Import Dependency:                                     │
│ └─ ADMIN_ROLE controls everything                           │
│    └─ If admin compromised → all access compromised         │
│    └─ Mitigation: Multi-sig or decentralized governance     │
└─────────────────────────────────────────────────────────────┘
```

---

End of Visual Diagrams
