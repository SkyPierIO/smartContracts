# Skypier Smart Contract - Persona Function Flow & User Journey Analysis

**Compiled by:** Senior Smart Contract Engineer  
**Date:** April 13, 2026  
**System:** Skypier VPN & Ecosystem Contracts  
**Solidity Version:** 0.8.24

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Persona Overview](#persona-overview)
3. [Detailed User Journeys](#detailed-user-journeys)
4. [Operation Dependency Analysis](#operation-dependency-analysis)
5. [Function Flow Diagrams](#function-flow-diagrams)
6. [End-to-End Workflows](#end-to-end-workflows)
7. [Role Hierarchy & Prerequisites](#role-hierarchy--prerequisites)

---

## Executive Summary

The Skypier ecosystem defines **8 core personas**, each with distinct capabilities and operational flows. The system uses a **Role-Based Access Control (RBAC)** pattern with soulbound tokens/badges that enforce role hierarchy through prerequisite token holdings.

### Key Characteristics:
- **All tokens/badges are soulbound** (non-transferable except via mint/burn)
- **Hierarchical role structure** with prerequisite dependencies
- **Time-limited badges** using ExpiryManagement library (52-week default for employee/sponsor badges)
- **Two-phase operator onboarding** requiring validator approval
- **Payment-driven client access** via PaymentPool contract

---

## Persona Overview

| Persona | Token/Badge ID | Contract | Primary Function | Prerequisites | Expiry |
|---------|---|---|---|---|---|
| **ADMIN_BADGE** | 0 (AdminBadge) | [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol) | System-wide access control | BUILDER_BADGE | None |
| **CLIENT_ROLE** | 0 (ClientToken) | [ClientToken.sol](contracts/product/tokens/ClientToken.sol) | VPN access via payment | Payment deposit | Customizable |
| **OPERATOR_ROLE** | 2 (OperatorToken) | [OperatorToken.sol](contracts/product/tokens/OperatorToken.sol) | Node management & provision | VALIDATOR approval | None |
| **VALIDATOR_ROLE** | 3 (ValidatorToken) | [ValidatorToken.sol](contracts/product/tokens/ValidatorToken.sol) | Operator validation & staking | Staking setup | None |
| **BUILDER_ROLE** | 4 (BuilderToken) | [BuilderToken.sol](contracts/internal/tokens/BuilderToken.sol) | System parameter management | Admin grant only | None |
| **EMPLOYEE_BADGE** | 5 (EmployeeBadge) | [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol) | Performance tracking | BUILDER_BADGE holder | 52 weeks (default) |
| **BETA_TESTER_BADGE** | 6 (BetaTesterBadge) | [SkypierBadges.sol](contracts/product/tokens/SkypierBadges.sol) | Early feature access | Minter role | Optional |
| **PROJECT_SPONSOR_BADGE** | 7 (ProjectSponsorBadge) | [ProjectSponsorBadge.sol](contracts/community/ProjectSponsorBadge.sol) | Project lifecycle tracking | Admin grant only | 52 weeks (fixed) |

---

## Detailed User Journeys

### 1. CLIENT PERSONA - VPN User Journey

**Purpose:** Access Skypier VPN network via payment mechanism  
**Token Type:** Soulbound ERC1155  
**Duration:** Variable (customizable expiry)

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT USER JOURNEY                           │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: ONBOARDING
├── Step 1.1: User initiates deposit
│   └── Function: PaymentPool.deposit() [external payable]
│       Input: ETH amount >= paymentAmount
│       Contract: PaymentPool
│       Access: Public
│
├── Step 1.2: Payment validation & tracking
│   └── State Update: PaymentPool.totalClientDeposits += msg.value
│       Event: ClientDeposit(address indexed client, uint256 amount)
│
├── Step 1.3: CLIENT_BADGE issuance (AUTOMATIC/MANUAL)
│   └── Function: ClientToken.mint(to, CLIENT_BADGE, amount, metadata)
│       Called by: PaymentPool or Admin
│       Role Required: MINTER_ROLE
│       Contract: ClientToken
│       Input: User address, badge ID (0), amount (1)
│
└── Step 1.4: Expiry setup (optional)
    └── Function: ClientToken.setExpiry(tokenId, expiryTime)
        Called by: Admin
        Role Required: DEFAULT_ADMIN_ROLE
        Default Duration: Custom per deployment

PHASE 2: VPN USAGE
├── Step 2.1: Check client status
│   └── Function: ClientToken.balanceOf(userAddress, CLIENT_BADGE)
│       Returns: 1 if valid, 0 if revoked
│
├── Step 2.2: Verify token not expired
│   └── Function: ClientToken.isExpired(tokenId)
│       Returns: bool (true if expired)
│
└── Step 2.3: Node connection allowed if balance > 0 && !isExpired

PHASE 3: TOKEN LIFECYCLE
├── Step 3.1: CLIENT_BADGE renewal
│   └── Function: ClientToken.mint(to, CLIENT_BADGE, 1, newMetadata)
│       Called by: PaymentPool after new deposit
│
├── Step 3.2: Revocation (lapsed payment/breach)
│   └── Function: ClientToken.burn(from, CLIENT_BADGE, 1)
│       Called by: Admin/Burner role
│       Role Required: BURNER_ROLE
│
└── Step 3.3: Emit revocation event
    └── Event: BadgeRevoked(address indexed account, uint256 tokenId, uint256 amount)
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Effects |
|----------|----------|--------|-----------|---------|
| `deposit()` | PaymentPool | Public | `{payable}` | Records client contribution, triggers badge mint |
| `mint()` | ClientToken | MINTER_ROLE | `to, tokenId, amount, metadata` | Issues CLIENT_BADGE soulbound token |
| `burn()` | ClientToken | BURNER_ROLE | `from, tokenId, amount` | Revokes CLIENT_BADGE, emits event |
| `setExpiry()` | ClientToken | ADMIN | `tokenId, expiryTime` | Sets absolute expiry timestamp |
| `isExpired()` | ClientToken | Public view | `tokenId` | Returns true if token is expired |
| `balanceOf()` | ClientToken | Public view | `account, tokenId` | Returns balance (0 or 1) |

#### Storage Changes:
```
PaymentPool:
├── operators[address] → Participant {wallet, lastPayment, totalContribution, isActive}
├── totalClientDeposits → uint256
└── lastDistributionTime → uint256

ClientToken:
├── balances[address][tokenId] → uint256 (0 or 1)
├── expiries[tokenId] → ExpiryInfo {expiryTime, isActive}
└── operatorSupplies[tokenId] → uint256
```

#### Soulbound Enforcement:
```solidity
// CLIENT_BADGE is Non-Transferable
function _update(from, to, ids, values) {
    require(from == address(0) || to == address(0), "Client token is soulbound");
}
```

---

### 2. OPERATOR PERSONA - Node Management Journey

**Purpose:** Run VPN nodes, earn staking rewards, manage network infrastructure  
**Token Type:** Soulbound ERC1155 (1 operator = 1 token)  
**Required Prerequisite:** VALIDATOR_ROLE approval

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                 OPERATOR USER JOURNEY                            │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: APPLICATION & WAITLIST
├── Step 1.1: Operator applies to network
│   └── Function: SkypierVPN.applyAsOperator(peerId)
│       Called by: Prospective operator (public)
│       Input: P2P peer ID string
│       Validation:
│       ├── require(!revokedOperators[msg.sender])
│       └── require(!nodes[msg.sender].isActive)
│
├── Step 1.2: Entry into waitlist
│   └── State Update: 
│       ├── operatorPeerIds[msg.sender] = _peerId
│       └── operatorWaitlist.push(msg.sender)
│
└── Step 1.3: Emit notification
    └── Event: OperatorAddedToWaitlist(address indexed operator)

PHASE 2: VALIDATOR APPROVAL (TWO-PHASE VALIDATION)
├── Step 2.1: Validator reviews application
│   └── Function: SkypierVPN.validateOperator(operator, peerId)
│       Called by: VALIDATOR_ROLE (validator address)
│       Role Required: VALIDATOR_ROLE (checked via onlyRole modifier)
│       Validation:
│       └── require(bytes(operatorPeerIds[_operator]).length > 0)
│
├── Step 2.2: Node registration
│   └── State Update:
│       nodes[_operator] = Node {
│           owner: _operator,
│           peerId: _peerId,
│           isActive: true,
│           registeredAt: block.timestamp,
│           lastHeartbeat: block.timestamp
│       }
│
├── Step 2.3: OPERATOR_TOKEN minting
│   └── Function: OperatorToken.mint(operator, nodeId) → tokenId
│       Called by: SkypierVPN contract
│       Role Required: MINTER_ROLE
│       Returns: uint256 (unique operator token ID)
│
└── Step 2.4: Node activation complete
    └── Event: NodeRegistered(address indexed owner, string peerId)
       Event: OperatorRegistered(uint256 indexed tokenId, string nodeId, address owner)

PHASE 3: ACTIVE OPERATION
├── Step 3.1: Heartbeat tracking
│   └── Function: SkypierVPN.heartbeat(operatorAddress)
│       Called by: Operator (periodic, off-chain trigger)
│       Effect: nodes[operator].lastHeartbeat = block.timestamp
│
├── Step 3.2: Monitor node status via NodeStatusContract
│   └── Contract: NodeStatusContract
│       Functions:
│       ├── getNodeStatus(nodeId) → NodeStatus
│       ├── reportNodeDown(nodeId)
│       └── registerNodeUp(nodeId)
│
├── Step 3.3: Query staking/rewards via PaymentPool
│   └── Contract: PaymentPool
│       State: operators[address] → Participant
│       Fields:
│       ├── lastPayment: timestamp of last reward
│       ├── totalContribution: cumulative earnings
│       └── isActive: current status
│
└── Step 3.4: Earn from network payments (Bi-weekly distribution)
    └── Function: PaymentPool.distributePayments()
        Called by: PAYMENT_MANAGER (periodic)
        Distribution Logic:
        ├── Check: block.timestamp >= lastDistributionTime + BIOWEEKLY_INTERVAL
        ├── For each operator: transfer(wallet, operatorShare)
        └── Update: operators[operator].lastPayment = block.timestamp

PHASE 4: REVOCATION/OFFBOARDING
├── Step 4.1: Operator revocation (breach/exit)
│   └── Function: SkypierVPN.revokeOperator(operatorAddress)
│       Called by: ADMIN_ROLE
│       Effect:
│       ├── revokedOperators[operator] = true
│       └── nodes[operator].isActive = false
│
├── Step 4.2: Token burn
│   └── Function: OperatorToken.deregisterOperator(tokenId)
│       Called by: BURNER_ROLE
│       Effect:
│       ├── operatorInfo[tokenId].isActive = false
│       └── Event: OperatorUnregistered(uint256 indexed tokenId)
│
└── Step 4.3: Node deactivation
    └── Function: SkypierVPN.revokeNode(operatorAddress)
        Called by: ADMIN_ROLE
        Event: NodeRevoked(address indexed owner)
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Preconditions |
|----------|----------|--------|-----------|---|
| `applyAsOperator()` | SkypierVPN | Public | `peerId: string` | !revoked, !already_operator |
| `validateOperator()` | SkypierVPN | VALIDATOR_ROLE | `_operator, _peerId` | On waitlist |
| `mint()` | OperatorToken | MINTER_ROLE | `to, nodeId` | Returns tokenId |
| `heartbeat()` | SkypierVPN | Operator | `operatorAddress` | Must own operator token |
| `deregisterOperator()` | OperatorToken | BURNER_ROLE | `tokenId` | Token exists |
| `revokeOperator()` | SkypierVPN | ADMIN_ROLE | `operatorAddress` | Must be active |

#### Critical Dependency: VALIDATOR_ROLE

Without a VALIDATOR_ROLE holder approving the operator, the operator **cannot achieve active status**. This is enforced at:
```solidity
function validateOperator(address _operator, string memory _peerId) 
    external 
    onlyRole(VALIDATOR_ROLE)  // ← MANDATORY DEPENDENCY
```

---

### 3. VALIDATOR PERSONA - Network Oversight Journey

**Purpose:** Approve operators, manage staking, validate network integrity  
**Token Type:** Soulbound ERC1155  
**Prerequisite:** Staking setup & minimum stake requirement

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                 VALIDATOR USER JOURNEY                           │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: VALIDATOR REGISTRATION (STAKING)
├── Step 1.1: Transfer staking tokens
│   └── Function: [External ERC20].transfer(validatorAddress, stakingAmount)
│       Input: Minimum staking amount (contract-defined)
│       Purpose: Collateral for validator accountability
│
├── Step 1.2: Register validator with stake
│   └── Function: ValidatorToken.mintValidatorBadge(validatorAddress, stakingAmount)
│       Called by: MINTER_ROLE
│       Input:
│       ├── validatorAddress: EOA of validator
│       └── stakingAmount: uint256 (checked > 0)
│
├── Step 1.3: VALIDATOR_BADGE minting
│   └── State Update:
│       validators[validatorAddress] = ValidatorInfo {
│           validatorAddress: address,
│           stakingAmount: uint256,
│           registeredAt: block.timestamp,
│           isActive: true
│       }
│
├── Step 1.4: Token issuance (1155)
│   └── _mint(validatorAddress, VALIDATOR_BADGE, 1, "")
│
└── Step 1.5: Validator ready for duty
    └── Event: ValidatorRegistered(address indexed validator, uint256 stakingAmount)

PHASE 2: OPERATOR VALIDATION
├── Step 2.1: Monitor operator waitlist
│   └── Function: SkypierVPN.operatorWaitlist (public array)
│       Access: Read-only view
│
├── Step 2.2: Review operator application
│   └── Off-chain: Validator evaluates operator credentials
│       ├── Check: Node ID validity
│       ├── Check: Operator reputation/kyc
│       └── Check: Staking amount adequacy
│
├── Step 2.3: Validate operator (on-chain)
│   └── Function: SkypierVPN.validateOperator(operatorAddress, peerId)
│       Called by: Validator (VALIDATOR_ROLE holder)
│       Role Check: onlyRole(VALIDATOR_ROLE)
│       Effect:
│       ├── Create Node struct
│       ├── Mint OPERATOR_TOKEN to operator
│       └── Transition operator from WAITLIST → ACTIVE
│
├── Step 2.4: Delegation & tracking
│   └── Off-chain state: Validator maintains list of validated operators
│
└── Step 2.5: Success notification
    └── Event: OperatorValidated(address indexed operator, string peerId)

PHASE 3: ONGOING VALIDATION
├── Step 3.1: Monitor operator performance
│   └── Contract: NodeStatusContract
│       Functions:
│       ├── getNodeStatus(nodeId) → status
│       └── reportNodeDown(nodeId)
│
├── Step 3.2: Stake slashing (optional implementation)
│   └── If operator misbehaves:
│       └── Function: ValidatorToken.revokeValidatorBadge(operatorAddress)
│           Effect: Reduce stakingAmount or revoke badge
│
└── Step 3.3: Track validation metrics
    └── Tracking: Number of operators validated, success rate

PHASE 4: VALIDATOR REVOCATION
├── Step 4.1: Validator exit or breach
│   └── Function: ValidatorToken.revokeValidatorBadge(validatorAddress)
│       Called by: BURNER_ROLE (admin)
│       Effect:
│       ├── _burn(validatorAddress, VALIDATOR_BADGE, 1)
│       └── validators[validatorAddress].isActive = false
│
├── Step 4.2: Stake recovery
│   └── Transfer staking amount back to validator wallet
│
└── Step 4.3: Revocation confirmation
    └── Event: ValidatorDeregistered(address indexed validator)
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Preconditions |
|----------|----------|--------|-----------|---|
| `mintValidatorBadge()` | ValidatorToken | MINTER_ROLE | `to, stakingAmount` | stakingAmount > 0 |
| `validateOperator()` | SkypierVPN | VALIDATOR_ROLE | `_operator, _peerId` | VALIDATOR_ROLE held |
| `revokeValidatorBadge()` | ValidatorToken | BURNER_ROLE | `validatorAddress` | Must be active validator |
| `getValidatorInfo()` | ValidatorToken | Public view | `validatorAddress` | N/A |

#### Critical Dependency Chain:
```
Validator Stake Deposited → ValidatorBadge Minted → VALIDATOR_ROLE Granted → Can validate operators
                                     ↓
                        Can call SkypierVPN.validateOperator()
                                     ↓
                        Operators transition from WAITLIST → ACTIVE
```

---

### 4. BUILDER PERSONA - System Architecture & Parameter Management

**Purpose:** Manage system parameters, create/control badges, oversee employee hierarchy  
**Token Type:** Soulbound ERC1155 (1155-based)  
**Prerequisite:** Admin grant (top-level role)

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                 BUILDER USER JOURNEY                             │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: BUILDER GRANT (ADMIN ONLY)
├── Step 1.1: Admin grants BUILDER_ROLE
│   └── Function: BuilderToken.mintBuilderToken(to)
│       Called by: DEFAULT_ADMIN_ROLE only
│       Validation: hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
│
├── Step 1.2: BUILDER_BADGE minting
│   └── State Update: _mint(to, BUILDER_BADGE, 1, "")
│       Token ID: 0
│       Amount: 1 (soulbound)
│
└── Step 1.3: Builder capabilities unlocked
    └── Builder can now:
        ├── Create EMPLOYEE_BADGE
        ├── Create ADMIN_BADGE
        ├── Manage system parameters
        └── Delegate to other builders (via ADMIN)

PHASE 2: EMPLOYEE BADGE MANAGEMENT
├── Step 2.1: Initialize EmployeeBadge contract
│   └── Function: EmployeeLevelBadge.initialize(uri, _builderToken, _builderTokenId, expiryDuration, admin)
│       Parameters:
│       ├── _builderToken: BuilderToken contract address
│       ├── _builderTokenId: 0 (BUILDER_BADGE)
│       └── _expiryDuration: 52 weeks (customizable)
│
├── Step 2.2: Mint EMPLOYEE_BADGE
│   └── Function: EmployeeLevelBadge.mintEmployeeLevelBadge(to, amount, customExpiryDuration)
│       Called by: BUILDER_BADGE holder + ADMIN
│       Preconditions:
│       ├── require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0)
│       ├── require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
│       └── amount <= WALLET_CAP (6)
│
├── Step 2.3: Expiry setup
│   └── State Update:
│       _expiry[tokenId].setExpiry(dur)
│       // Sets: expiryTime = block.timestamp + duration, isActive = true
│
├── Step 2.4: Track employee performance
│   └── Stored in: _badgeHolders[address] → BadgeHolder {mintTime}
│
└── Step 2.5: Employee badge expiry handling
    └── Function: EmployeeLevelBadge.burnExpiredBadges(from, tokenId)
        Called by: ADMIN
        Preconditions: require(_expiry[tokenId].isExpired())

PHASE 3: ADMIN BADGE DELEGATION
├── Step 3.1: Create new admin
│   └── Function: AdminBadge.mintAdminBadge(to)
│       Called by: BUILDER_BADGE holder + ADMIN
│       Preconditions:
│       ├── require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0)
│       └── require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
│
├── Step 3.2: ADMIN_BADGE minting
│   └── State Update:
│       uint256 tokenId = _nextTokenId++
│       _safeMintWithRole(to, tokenId, 1, "")
│
├── Step 3.3: Dual role assignment
│   └── Effect:
│       ├── ERC1155 token minted (soulbound)
│       └── grantRole(DEFAULT_ADMIN_ROLE, to) ← Enables access control
│
└── Step 3.4: Admin revocation
    └── Function: AdminBadge.burnAdminBadge(from, tokenId)
        Called by: ADMIN_ROLE
        Effect:
        ├── _safeBurnWithRole(from, tokenId, 1)
        └── revokeRole(DEFAULT_ADMIN_ROLE, from)

PHASE 4: SYSTEM PARAMETER MANAGEMENT
├── Step 4.1: Update client payment amount
│   └── Function: PaymentPool.setPaymentAmount(newAmount)
│       Called by: PAYMENT_MANAGER (typically BUILDER_ROLE)
│       Effect: paymentAmount = newAmount
│           (Required amount to receive CLIENT_BADGE)
│
├── Step 4.2: Configure staking requirements
│   └── Function: SkypierVPN.setStakeAmount(newAmount)
│       Called by: ADMIN_ROLE
│       Effect: stakeAmount = newAmount
│           (Minimum stake for validators)
│
├── Step 4.3: Manage payment distribution intervals
│   └── Function: PaymentPool.setDistributionInterval(newInterval)
│       Called by: PAYMENT_MANAGER
│       Effect: BIOWEEKLY_INTERVAL = newInterval
│           (Default: 14 days)
│
└── Step 4.4: Update wallet allocation pools
    └── Function: PaymentPool.setWallets(networkPool, builderPool, developerPool)
        Called by: ADMIN_ROLE
        Effect: Configure revenue distribution

PHASE 5: HUMAN RESOURCES OVERSIGHT (Builder → HumanResources)
├── Step 5.1: Register builder in HR system
│   └── Function: HumanResources.registerBuilder(builderAddress, role, monthlyAllocation)
│       Called by: HR_MANAGER_ROLE
│       Effect:
│       builders[builderAddress] = Builder {
│           wallet: builderAddress,
│           role: "Senior Engineer", // example
│           monthlyAllocation: 50000, // in wei
│           lastPaymentTime: block.timestamp,
│           isActive: true
│       }
│
├── Step 5.2: Update allocation
│   └── Function: HumanResources.updateBuilderAllocation(builderAddress, newAllocation)
│       Called by: HR_MANAGER_ROLE
│       Effect: Adjust monthly payout amount
│
├── Step 5.3: Process monthly payments
│   └── Function: HumanResources.processPayment(builderAddress)
│       Called by: TREASURER_ROLE
│       Effect:
│       ├── Check: block.timestamp >= lastPaymentTime + 30 days
│       └── Transfer: builderPoolWallet → builderAddress (monthlyAllocation)
│
└── Step 5.4: Deregister builder (offboarding)
    └── Function: HumanResources.deregisterBuilder(builderAddress)
        Called by: HR_MANAGER_ROLE
        Effect: Set isActive = false, stop payments
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Effects |
|----------|----------|--------|-----------|---------|
| `mintBuilderToken()` | BuilderToken | ADMIN | `to` | Issues BUILDER_BADGE |
| `mintEmployeeLevelBadge()` | EmployeeLevelBadge | BUILDER+ADMIN | `to, amount, customExpiry` | Creates EMPLOYEE_BADGE |
| `mintAdminBadge()` | AdminBadge | BUILDER+ADMIN | `to` | Mints token + grants ADMIN role |
| `burnAdminBadge()` | AdminBadge | ADMIN | `from, tokenId` | Revokes token + admin role |
| `registerBuilder()` | HumanResources | HR_MANAGER | `address, role, allocation` | Sets up HR record |
| `processPayment()` | HumanResources | TREASURER | `builderAddress` | Distributes monthly allocation |

#### Prerequisite Chain:
```
Admin: Grant BUILDER_BADGE to Builder
              ↓
      Builder can mint EMPLOYEE_BADGE
              ↓
      Builder can mint ADMIN_BADGE
              ↓
      New Admin can manage system parameters
```

---

### 5. EMPLOYEE BADGE PERSONA - Performance & Contribution Tracking

**Purpose:** Track employee contributions, time-limited performance incentives  
**Token Type:** Soulbound ERC1155 with expiry  
**Duration:** 52 weeks (customizable) from issuance  
**Controlled By:** BUILDER_BADGE holder

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│              EMPLOYEE BADGE USER JOURNEY                         │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: INITIAL SETUP (BUILDER)
├── Step 1.1: Builder initializes EmployeeBadge contract
│   └── Function: EmployeeLevelBadge.initialize()
│       Called by: Deployer/Admin
│       Parameters:
│       ├── _builderToken: BuilderToken contract
│       ├── _builderTokenId: 0 (BUILDER_BADGE ID)
│       └── _expiryDuration: 52 weeks = 31,536,000 seconds
│
└── Step 1.2: Set default expiry duration
    └── Function: EmployeeLevelBadge.setDefaultExpiryDuration(duration)
        Called by: DEFAULT_ADMIN_ROLE
        Effect: expiryDuration = duration (global default)

PHASE 2: BADGE ISSUANCE
├── Step 2.1: Builder determines employee's badge entitlement
│   └── Off-chain decision: Performance review, contribution level
│
├── Step 2.2: Mint EMPLOYEE_BADGE
│   └── Function: EmployeeLevelBadge.mintEmployeeLevelBadge(to, amount, customExpiryDuration)
│       Called by: BUILDER_BADGE holder + ADMIN_ROLE
│       Validation:
│       ├── require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0)
│       ├── require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
│       ├── require(amount <= WALLET_CAP) // Max 6 badges per wallet
│       └── require(to != address(0))
│
├── Step 2.3: Token creation
│   └── State Update:
│       uint256 tokenId = _nextTokenId++
│       _safeMintWithRole(to, tokenId, amount, "")
│       // This calls ERC1155._mint(to, tokenId, amount, "")
│
├── Step 2.4: Expiry configuration
│   └── State Update:
│       uint256 dur = customExpiryDuration > 0 ? customExpiryDuration : expiryDuration
│       _expiry[tokenId].setExpiry(dur)
│       // Sets: expiryTime = block.timestamp + dur, isActive = true
│
└── Step 2.5: Confirmation
    └── Event: BadgeExpired(uint256 indexed tokenId, uint256 expiryTime)
       (Note: Event name is "BadgeExpired" but actually represents issuance with expiry set)

PHASE 3: ACTIVE TENURE
├── Step 3.1: Employee holds badge
│   └── State: balances[employeeAddress][tokenId] = amount (typically 1)
│       Verification: EmployeeLevelBadge.hasBadge(address, tokenId) → bool
│
├── Step 3.2: Monitor expiry timer
│   └── Function: EmployeeLevelBadge.getBadgeExpiry(tokenId) → uint256
│       Returns: Absolute timestamp when badge expires
│       Formula: expiryTime = mintTime + expiryDuration
│
├── Step 3.3: Check time remaining
│   └── Function: LibExpiryManagement.getTimeRemaining(info) → uint256
│       Returns: block.timestamp - expiryTime (or 0 if expired)
│
└── Step 3.4: Access to benefits (off-chain checks)
    └── VPN/network: Check balanceOf(employee, badgeTokenId) > 0 && !isExpired()

PHASE 4: BADGE RENEWAL
├── Step 4.1: Builder evaluates performance renewal
│   └── Off-chain: Review contribution metrics post-expiry decision
│
├── Step 4.2: Extend existing badge expiry
│   └── Function: EmployeeLevelBadge.extendExpiry(tokenId, additionalDuration)
│       Called by: DEFAULT_ADMIN_ROLE
│       Effect:
│       _expiry[tokenId].extendExpiry(additionalDuration)
│       // New expiryTime = expiryTime + additionalDuration
│
├── Step 4.3: Issue new badge (alternative)
│   └── Function: EmployeeLevelBadge.mintEmployeeLevelBadge(to, amount, duration)
│       Effect: Create new tokenId with fresh expiry
│
└── Step 4.4: Emit renewal notification
    └── Event: ExpiryExtended(uint256 indexed tokenId, uint256 newExpiryTime)

PHASE 5: BADGE EXPIRATION HANDLING
├── Step 5.1: Badge expires (automatic)
│   └── Expiry check: block.timestamp >= expiryTime
│       Function: EmployeeLevelBadge.isExpired(tokenId) → bool
│
├── Step 5.2: Revocation of expired badges
│   └── Function: EmployeeLevelBadge.burnExpiredBadges(from, tokenId)
│       Called by: DEFAULT_ADMIN_ROLE
│       Preconditions:
│       ├── require(_expiry[tokenId].isExpired())
│       └── require(balanceOf(from, tokenId) > 0)
│
├── Step 5.3: Token burn
│   └── _safeBurnWithRole(from, tokenId, 1)
│       Effect: balances[from][tokenId] = 0
│
├── Step 5.4: Cleanup
│   └── _expiry[tokenId].revokeExpiry()
│       Effect: isActive = false
│
└── Step 5.5: Confirmation
    └── Event: BadgeExpired(uint256 indexed tokenId, uint256 expiryTime)

PHASE 6: OFFBOARDING
├── Step 6.1: Employee termination
│   └── Off-chain: HR notifies smart contract admin
│
├── Step 6.2: Manual badge revocation
│   └── Function: EmployeeLevelBadge.burnExpiredBadges(employeeAddress, tokenId)
│       (Can be called even if not expired)
│       Effect: Immediately revokes badge
│
└── Step 6.3: Final cleanup
    └── All balances[employeeAddress][*] → 0
       All _expiry[*].isActive → false
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Effects |
|----------|----------|--------|-----------|---------|
| `mintEmployeeLevelBadge()` | EmployeeLevelBadge | BUILDER+ADMIN | `to, amount, customExpiry` | Issues EMPLOYEE_BADGE with expiry |
| `extendExpiry()` | EmployeeLevelBadge | ADMIN | `tokenId, additionalDuration` | Extends badge expiry |
| `burnExpiredBadges()` | EmployeeLevelBadge | ADMIN | `from, tokenId` | Revokes expired/terminated badge |
| `isExpired()` | EmployeeLevelBadge | Public view | `tokenId` | Returns true if expired |
| `getBadgeExpiry()` | EmployeeLevelBadge | Public view | `tokenId` | Returns absolute expiry timestamp |
| `hasBadge()` | EmployeeLevelBadge | Public view | `holder, tokenId` | Returns true if balance > 0 |

#### Expiry Management:
```
Issuance:     block.timestamp = T
expiryTime = T + 52 weeks

Active Period: T ≤ block.timestamp < T + 52 weeks
isExpired() → false
isValid() → true

Expired:      block.timestamp ≥ T + 52 weeks
isExpired() → true
isValid() → false
burnExpiredBadges() can be called

Extension:    expiryTime = T + 52 weeks + extension
extendExpiry(additionalDuration)
```

---

### 6. ADMIN BADGE PERSONA - Top-Level System Control

**Purpose:** Full system access, parameter control, emergency management  
**Token Type:** Soulbound ERC1155 + AccessControl role  
**Dual Nature:** Both ERC1155 token AND DEFAULT_ADMIN_ROLE grant  
**Prerequisite:** BUILDER_BADGE holder must mint

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                 ADMIN BADGE USER JOURNEY                         │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: ADMIN PROMOTION (BUILDER INITIATION)
├── Step 1.1: BUILDER_BADGE holder initiates admin creation
│   └── Function: AdminBadge.mintAdminBadge(to)
│       Called by: BUILDER_BADGE holder + ADMIN_ROLE
│       Preconditions:
│       ├── require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0)
│       └── require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
│
├── Step 1.2: Dual activation - Token + Role
│   └── State Update 1: ERC1155 minting
│       uint256 tokenId = _nextTokenId++
│       _safeMintWithRole(to, tokenId, 1, "")
│       // Creates soulbound token
│
├── Step 1.3: Dual activation - AccessControl role
│   └── State Update 2: Role granting
│       grantRole(DEFAULT_ADMIN_ROLE, to)
│       // Now 'to' can:
│       // ├── Call onlyRole(DEFAULT_ADMIN_ROLE) functions
│       // ├── Authorize upgrades
│       // ├── Grant other roles
│       // └── Manage all sensitive parameters
│
└── Step 1.4: Confirmation
    └── Event: RoleGranted(address indexed account, bytes32 indexed role)

PHASE 2: SYSTEM ADMINISTRATION
├── Step 2.1: Grant/Revoke sub-roles
│   └── Function: [Any AccessControl contract].grantRole(role, account)
│       Called by: DEFAULT_ADMIN_ROLE holder
│       Manageable Roles:
│       ├── MINTER_ROLE (token/badge creation)
│       ├── BURNER_ROLE (token/badge destruction)
│       ├── PAUSER_ROLE (pause contract)
│       ├── PAYMENT_MANAGER (distribution management)
│       └── HR_MANAGER_ROLE (employee setup)
│
├── Step 2.2: Pause/Unpause contracts
│   └── Function: BaseAccessControlledUpgradeableToken.pause()
│       Called by: PAUSER_ROLE (delegated by ADMIN)
│       Effect: All mint/transfer operations blocked
│
├── Step 2.3: Token/Badge management
│   └── Functions available:
│       ├── mint() / burn() via delegated roles
│       ├── mintAdminBadge() / burnAdminBadge()
│       ├── mintEmployeeLevelBadge() / burnExpiredBadges()
│       └── mintValidatorBadge() / revokeValidatorBadge()
│
├── Step 2.4: SkypierVPN node management
│   └── Functions available:
│       ├── validateOperator(operator, peerId)
│       ├── revokeOperator(operator)
│       ├── revokeNode(operator)
│       └── setStakeAmount(amount)
│
├── Step 2.5: PaymentPool configuration
│   └── Functions available:
│       ├── setPaymentAmount(amount)
│       ├── setWallets(networkPool, builderPool, developerPool)
│       ├── distributePayments() [via PAYMENT_MANAGER]
│       └── emergencyWithdraw(amount)
│
├── Step 2.6: Contract upgrades (UUPS)
│   └── Function: [Upgradeable contract]._authorizeUpgrade(newImplementation)
│       Called by: DEFAULT_ADMIN_ROLE during upgrade
│       Effect: Approve new contract implementation
│       Pattern:
│       1. Deploy new implementation contract
│       2. Call proxy.upgradeToAndCall(newImpl, data)
│       3. _authorizeUpgrade(newImpl) validates admin
│       4. Proxy delegatecalls to new implementation
│
└── Step 2.7: Emergency pausals
    └── Callable by: PAUSER_ROLE (delegated by ADMIN)
        Action: Pause all token operations if security breach detected

PHASE 3: VALIDATOR MANAGEMENT (ADMIN-ONLY)
├── Step 3.1: Register validator with stake
│   └── Function: ValidatorToken.mintValidatorBadge(address, stakingAmount)
│       Called by: MINTER_ROLE
│       Effect: validator becomes able to validateOperator()
│
├── Step 3.2: Revoke validator
│   └── Function: ValidatorToken.revokeValidatorBadge(validatorAddress)
│       Called by: BURNER_ROLE
│       Effect: Remove operator validation authority
│
└── Step 3.3: Query validator status
    └── Function: ValidatorToken.getValidatorInfo(validatorAddress) → ValidatorInfo
        Effect: Access validators[address] struct

PHASE 4: HUMAN RESOURCES DELEGATION
├── Step 4.1: Delegate HR management
│   └── Function: HumanResources.grantRole(HR_MANAGER_ROLE, hrAddress)
│       Called by: DEFAULT_ADMIN_ROLE
│       Effect: Empower HR manager to registerBuilder(), updateAllocation()
│
├── Step 4.2: Setup builder payroll
│   └── Function: HumanResources.registerBuilder(builderAddr, role, allocation)
│       Called by: HR_MANAGER_ROLE
│       Effect: Add builder to payroll system
│
└── Step 4.3: Process monthly distributions
    └── Function: HumanResources.processPayment(builderAddress)
        Called by: TREASURER_ROLE
        Effect: Send monthly allocation to builder wallet

PHASE 5: ADMIN REVOCATION (DEMOTION)
├── Step 5.1: BUILDER or higher-level ADMIN demotes
│   └── Function: AdminBadge.burnAdminBadge(adminAddress, tokenId)
│       Called by: DEFAULT_ADMIN_ROLE
│       Validation: require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
│
├── Step 5.2: Token destruction
│   └── _safeBurnWithRole(adminAddress, tokenId, 1)
│       Effect: balances[adminAddress][tokenId] = 0
│
├── Step 5.3: Role revocation
│   └── revokeRole(DEFAULT_ADMIN_ROLE, adminAddress)
│       Effect: Admin access completely removed
│
└── Step 5.4: Confirmation
    └── Event: RoleRevoked(address indexed account, bytes32 indexed role)
       Admin can no longer call onlyRole(DEFAULT_ADMIN_ROLE) functions
```

#### Key Functions Available via ADMIN_BADGE:

| Function | Contract | Purpose | Critical |
|----------|----------|---------|----------|
| `grantRole()` | Access Control | Delegate roles | ✓ YES |
| `revokeRole()` | Access Control | Remove roles | ✓ YES |
| `pause()` | Tokens | Emergency freeze | ✓ YES |
| `unpause()` | Tokens | Resume operations | YES |
| `_authorizeUpgrade()` | All upgradeable | Approve upgrades | ✓ YES |
| `validateOperator()` | SkypierVPN | Approve operators | YES |
| `revokeOperator()` | SkypierVPN | Remove operators | YES |
| `setPaymentAmount()` | PaymentPool | Configure payments | YES |
| `mintAdminBadge()` | AdminBadge | Create new admin | ✓ YES |
| `burnAdminBadge()` | AdminBadge | Demote admin | ✓ YES |

#### Role Hierarchy Enforcement:
```solidity
// ADMIN requires BUILDER to exist first
function mintAdminBadge(address to) external {
    require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token");  // ← PREREQUISITE
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must be admin");  // ← CIRCULAR: Prevents initial promotion without existing admin
}

// Solution: First admin is granted during initialization
function initialize(address admin) public initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);  // Bootstrap step
}
```

---

### 7. BETA TESTER BADGE PERSONA - Early Access Features

**Purpose:** Grant early access to new features, testing privileges  
**Token Type:** Soulbound ERC1155  
**Duration:** Optional expiry (configured per badge)  
**Issued By:** MINTER_ROLE (typically builder)

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│              BETA TESTER BADGE USER JOURNEY                      │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: BETA TESTER IDENTIFICATION
├── Step 1.1: Admin/Builder identifies beta testers
│   └── Off-chain: Select trusted community members for early features
│
└── Step 1.2: Prepare beta testing wave
    └── Batch list of addresses ready for badging

PHASE 2: BADGE ISSUANCE
├── Step 2.1: Mint beta tester badge
│   └── Function: SkypierBadges.mintBadge(to, BETA_TESTER_BADGE_ID, amount, data)
│       Called by: MINTER_ROLE
│       Parameters:
│       ├── to: Beta tester address
│       ├── badgeId: 6 (BETA_TESTER_BADGE)
│       ├── amount: 1 (soulbound)
│       └── data: Optional metadata
│
├── Step 2.2: Badge attributes storage
│   └── State Update:
│       _badgeAttributes[badgeId][to] = BadgeAttributes {
│           holder: to,
│           issuer: msg.sender (MINTER_ROLE caller),
│           issuedAt: block.timestamp,
│           expiresAt: 0  // Optional (0 = no expiry)
│       }
│
├── Step 2.3: Optional expiry configuration
│   └── If expiry required:
│       Function: ClientToken.setExpiry(tokenId, expiryTime)
│       (Only if using ClientToken for beta testers)
│       OR
│       Update attributes: _badgeAttributes[badgeId][to].expiresAt = futureTime
│
└── Step 2.4: Activation confirmation
    └── Event: BadgeMinted(address indexed to, uint256 indexed tokenId, uint256 amount)

PHASE 3: FEATURE ACCESS
├── Step 3.1: Off-chain: Check beta tester status
│   └── Function: SkypierBadges.balanceOf(testerAddress, BETA_TESTER_BADGE_ID)
│       Returns: 1 if active beta tester, 0 otherwise
│
├── Step 3.2: Off-chain: Verify expiry (if configured)
│   └── If _badgeAttributes[badgeId][testerAddress].expiresAt > 0:
│       Allowed = block.timestamp <= expiresAt
│
├── Step 3.3: Grant early access
│   └── Pass allowlist to:
│       ├── SkypierVPN: Priority node access
│       ├── PaymentPool: Reduced payment amounts (configurable)
│       └── Feature gates: Advanced VPN modes
│
└── Step 3.4: Monitor feedback
    └── Off-chain: Collect usage metrics and feedback

PHASE 4: BADGE REVOCATION
├── Step 4.1: Beta test phase ends
│   └── Off-chain: Determine promotion to full access or removal
│
├── Step 4.2: Revoke beta tester badge
│   └── Function: SkypierBadges.revokeBadge(from, BETA_TESTER_BADGE_ID)
│       Called by: MINTER_ROLE
│       Effect:
│       uint256 balance = balanceOf(from, BETA_TESTER_BADGE_ID)
│       _burn(from, BETA_TESTER_BADGE_ID, balance)
│       delete _badgeAttributes[BETA_TESTER_BADGE_ID][from]
│
└── Step 4.3: Confirmation
    └── Event: BadgeMinted / or custom revocation tracking

PHASE 5: UPGRADE PATH
├── Step 5.1: Successful beta tester → CLIENT_BADGE path
│   └── Function: ClientToken.mint(testerAddress, CLIENT_BADGE, 1, metadata)
│       Called by: MINTER_ROLE
│       Effect: Tester gains full CLIENT access (payment may be waived)
│
├── Step 5.2: Revoke beta tester badge upon upgrade
│   └── Function: SkypierBadges.revokeBadge(testerAddress, BETA_TESTER_BADGE_ID)
│       (Optional if stacking badges is allowed)
│
└── Step 5.3: Notification
    └── Event: Transition from BETA_TESTER → CLIENT_ROLE
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Effects |
|----------|----------|--------|-----------|---------|
| `mintBadge()` | SkypierBadges | MINTER_ROLE | `to, badgeId, amount, data` | Issues badge with attributes |
| `revokeBadge()` | SkypierBadges | MINTER_ROLE | `from, badgeId` | Destroys badge |
| `getBadgeAttributes()` | SkypierBadges | Public view | `badgeId, holder` | Returns BadgeAttributes |
| `setExpiry()` | ClientToken | ADMIN | `tokenId, expiryTime` | Configures expiry (if using ClientToken) |
| `balanceOf()` | SkypierBadges | Public view | `account, tokenId` | Checks badge ownership |

#### Typical Beta Testing Flow:
```
1. Admin identifies community member
2. Call SkypierBadges.mintBadge(address, BETA_TESTER_BADGE_ID, 1, data)
3. Community member can access:
   - Early feature X
   - Discounted node rates
   - Priority support
4. After 4 weeks:
   - If successful: Mint ClientToken or promote to paid access
   - If unsuccessful: revokeBadge()
```

---

### 8. PROJECT SPONSOR BADGE PERSONA - Project Lifecycle Management

**Purpose:** Track project sponsorships, project partnerships, time-limited sponsorship status  
**Token Type:** Soulbound ERC1155 with fixed 52-week expiry  
**Issued By:** DEFAULT_ADMIN_ROLE only  
**Key Feature:** Project tracking with sponsor info

#### Function Flow:

```
┌─────────────────────────────────────────────────────────────────┐
│           PROJECT SPONSOR BADGE USER JOURNEY                     │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: PROJECT SETUP
├── Step 1.1: Admin identifies sponsorship opportunity
│   └── Off-chain: Match project needs with sponsor capabilities
│
└── Step 1.2: Prepare sponsorship parameters
    └── Define:
        ├── Project ID: Unique identifier (string)
        ├── Sponsor Address: Wallet of sponsor
        ├── Duration: Project length (optional, defaults to 52 weeks)
        └── Metadata: Project details

PHASE 2: BADGE ISSUANCE
├── Step 2.1: Mint PROJECT_SPONSOR_BADGE
│   └── Function: ProjectSponsorBadge.mintSponsorBadge(to, projectId, duration)
│       Called by: DEFAULT_ADMIN_ROLE
│       Parameters:
│       ├── to: Sponsor address
│       ├── projectId: Project identifier (e.g., "VPN_EXPANSION_Q2_2026")
│       └── duration: Project duration in seconds (0 = default 52 weeks)
│
├── Step 2.2: Validation & default handling
│   └── Preconditions:
│       ├── require(to != address(0))
│       └── if (duration == 0) duration = BADGE_EXPIRY; // 52 weeks
│
├── Step 2.3: Unique token generation
│   └── State Update:
│       uint256 tokenId = uint256(keccak256(abi.encodePacked(projectId, to, block.timestamp)))
│       // Ensures unique token ID per sponsor + project + time
│
├── Step 2.4: Expiry calculation (fixed 52 weeks from issuance)
│   └── State Update:
│       uint256 expiry = block.timestamp + duration
│       _expiryInfo[tokenId].setExpiryAbsolute(uint64(expiry))
│
├── Step 2.5: Project information storage
│   └── State Update:
│       _projectInfo[tokenId] = ProjectInfo {
│           projectId: projectId,       // e.g., "VPN_EXPANSION_Q2_2026"
│           startTime: block.timestamp, // Project start
│           endTime: expiry,            // Project end (52 weeks out)
│           sponsor: to                 // Sponsor address
│       }
│
├── Step 2.6: Token minting (soulbound)
│   └── _mint(to, tokenId, 1, "")
│       Effect: balances[to][tokenId] = 1
│
└── Step 2.7: Confirmation & tracking
    └── Event: BadgeMinted(uint256 indexed tokenId, string projectId, address sponsor, uint256 expiry)
       Enables off-chain indexing: TokenID → Project → Sponsor → Timeline

PHASE 3: ACTIVE SPONSORSHIP
├── Step 3.1: Query sponsor details
│   └── Function: ProjectSponsorBadge.getProjectInfo(tokenId) → ProjectInfo
│       Returns:
│       {
│           projectId: string,      // Project name
│           startTime: uint256,      // When badge was issued
│           endTime: uint256,        // When badge expires (52 weeks later)
│           sponsor: address         // Sponsor wallet
│       }
│
├── Step 3.2: Verify active sponsorship
│   └── Function: ProjectSponsorBadge.isValidBadge(tokenId) → bool
│       Returns: true if badge is valid and not expired
│       Logic: _expiryInfo[tokenId].isValid()
│           = (isActive && block.timestamp < expiryTime)
│
├── Step 3.3: Off-chain tracking
│   └── Frontend can:
│       ├── Display sponsor's active projects
│       ├── List project timeline (startTime → endTime)
│       ├── Show remaining sponsorship period
│       └── Generate sponsor metrics
│
└── Step 3.4: Sponsor benefits (application-dependent)
    └── Off-chain: Grant sponsor:
        ├── Project visibility/recognition
        ├── Preferential operator rates (if applicable)
        ├── Community voting rights (via DAO)
        └── Milestone bonus allocations

PHASE 4: BADGE MONITORING & RENEWAL
├── Step 4.1: Monitor expiration countdown
│   └── Function: ExpiryManagement.getTimeRemaining(expiryInfo) → uint256
│       Returns: Seconds until badge expires (0 if expired)
│
├── Step 4.2: Pre-expiration notification (off-chain)
│   └── Off-chain system:
│       ├── Query getProjectInfo(tokenId).endTime
│       ├── Alert sponsor if endTime - block.timestamp < 30 days
│       └── Offer renewal/extension options
│
├── Step 4.3: Renewal option 1 - Reissuance
│   └── Function: ProjectSponsorBadge.mintSponsorBadge(to, projectId, newDuration)
│       Effect: Create NEW tokenId with new expiry
│       (Old badge remains until burned)
│
├── Step 4.4: Renewal option 2 - Direct burn + reissue
│   └── Function: ProjectSponsorBadge._burn(sponsorAddress, oldTokenId, 1)
│       Called by: BURNER_ROLE (if implemented)
│       Then: mintSponsorBadge() to create new badge
│
└── Step 4.5: Continuous sponsorship
    └── No gap if reissuance occurs by endTime

PHASE 5: BADGE EXPIRATION
├── Step 5.1: Automatic expiration (time-based)
│   └── When block.timestamp >= endTime:
│       ├── isValidBadge(tokenId) → false
│       └── isExpired(tokenId) → true
│
├── Step 5.2: Off-chain actions upon expiration
│   └── Frontend/backend:
│       ├── Remove from active sponsorship list
│       ├── Archive project record
│       ├── Generate final project report
│       └── Notify sponsor of completion
│
├── Step 5.3: Sponsor exit
│   └── Sponsor retains badge in wallet (soulbound, cannot burn)
│       But badge provides NO benefits (isExpired = true)
│
└── Step 5.4: Archival state
    └── Badge exists as historical record:
        ├── Sponsorship dates: startTime → endTime
        ├── Project ID: Immutable
        └── Sponsor address: Immutable

PHASE 6: PROJECT CANCELLATION (EARLY TERMINATION)
├── Step 6.1: Admin decides to end project early
│   └── Off-chain: Business decision to terminate sponsorship
│
├── Step 6.2: Manual badge burning (if implemented)
│   └── Note: Current implementation doesn't include burn()
│       Suggestion: Add function for emergency revocation
│       Function: ProjectSponsorBadge.revokeSponsorBadge(sponsorAddress, tokenId)
│       Called by: DEFAULT_ADMIN_ROLE
│       Effect: _burn(sponsorAddress, tokenId, 1)
│
└── Step 6.3: Project termination notification
    └── Event: Custom event or external logging
       Reason: "EARLY_TERMINATION" or "SPONSOR_BREACH"
```

#### Key Functions Reference:

| Function | Contract | Access | Parameters | Returns |
|----------|----------|--------|-----------|---------|
| `mintSponsorBadge()` | ProjectSponsorBadge | ADMIN | `to, projectId, duration` | Creates badge + stores ProjectInfo |
| `getProjectInfo()` | ProjectSponsorBadge | Public view | `tokenId` | ProjectInfo struct |
| `isValidBadge()` | ProjectSponsorBadge | Public view | `tokenId` | bool (true if active & not expired) |
| `balanceOf()` | ProjectSponsorBadge | Public view | `sponsor, tokenId` | uint256 (0 or 1) |

#### Project Sponsor Badge Lifecycle:
```
T₀: Issuance
├── admin.mintSponsorBadge(sponsor, "Q2_PROJECT", 0)
├── tokenId = keccak256(projectId, sponsor, T₀)
├── endTime = T₀ + 52 weeks
└── isValidBadge(tokenId) → true

T₀ to T₀+52w: Active Sponsorship
├── getProjectInfo(tokenId) → {projectId, T₀, T₀+52w, sponsor}
├── isValidBadge(tokenId) → true
└── Sponsor benefits active

T₀+52w: Expiration
├── isValidBadge(tokenId) → false
├── isExpired(tokenId) → true
└── Badge remains (soulbound history)

Post-Expiration: Archive/Renewal
├── Sponsor can be re-badged with new project
├── Or badge remains as historical record
└── getProjectInfo() still accessible for auditing
```

#### Event Tracking:
```
BadgeMinted(uint256 indexed tokenId, string projectId, address sponsor, uint256 expiry)

Off-chain indexing enables:
├── Timeline: All projects with sponsors
├── Sponsor analytics: Projects + earned benefits
├── Project metrics: Duration, sponsors, status
└── Governance: Voting data sources from active badges
```

---

## Operation Dependency Analysis

### Dependency Graph - Functional Dependencies

```
┌────────────────────────────────────────────────────────────────┐
│     SYSTEM INITIALIZATION & PREREQUISITES                       │
└────────────────────────────────────────────────────────────────┘

Level 0: BOOTSTRAP (Admin-only initialization)
    ├─ BuilderToken.initialize() → Enables minting
    ├─ SkypierVPN.initialize(badges, skypierToken, paymentPool, stakeAmount)
    ├─ PaymentPool.initialize(...)
    ├─ ValidatorToken.initialize()
    ├─ OperatorToken.initialize()
    ├─ ClientToken.initialize(minter, admin)
    ├─ HumanResources.initialize(builderPoolWallet)
    ├─ EmployeeLevelBadge.initialize(uri, builderToken, BUILDER_BADGE_ID, 52 weeks, admin)
    ├─ AdminBadge.initialize(uri, builderToken, BUILDER_BADGE_ID, admin)
    ├─ ProjectSponsorBadge.initialize()
    └─ SkypierBadges.initialize()

Level 1: INITIAL ROLE GRANTING (Admin distributes authority)
    ├─ BuilderToken.mintBuilderToken(builderAddresses)
    │   └─ Prerequisite: Caller has DEFAULT_ADMIN_ROLE
    │   └─ Enables: BUILDER personas
    │
    ├─ ValidatorToken.mintValidatorBadge(validatorAddresses, stakingAmount)
    │   └─ Prerequisite: Caller has MINTER_ROLE
    │   └─ Enables: VALIDATOR personas to validate operators
    │
    ├─ HumanResources.registerBuilder(builderAddress, role, allocation)
    │   └─ Prerequisite: Caller has HR_MANAGER_ROLE
    │   └─ Enables: PaymentPool access for builders
    │
    └─ AdminBadge.mintAdminBadge(adminAddresses)
        └─ Prerequisite: BUILDER_BADGE holder + ADMIN_ROLE
        └─ Enables: NEW admins to manage system

Level 2: CLIENT & OPERATOR FLOWS (Service users)
    │
    ├─┬─ CLIENT ROLE INITIATION
    │ ├─ PaymentPool.deposit() [public]
    │ │   └─ Effect: totalClientDeposits += msg.value
    │ │   └─ Triggers: ClientToken.mint(client, CLIENT_BADGE)
    │ │   └─ Enables: VPN access
    │ │
    │ └─ ClientToken.mint(client, CLIENT_BADGE, 1, metadata)
    │     └─ Prerequisite: MINTER_ROLE
    │     └─ Effect: balanceOf[client][CLIENT_BADGE] = 1
    │
    ├─┬─ OPERATOR ROLE INITIATION
    │ ├─ SkypierVPN.applyAsOperator(peerId) [public]
    │ │   └─ Effect: Added to operatorWaitlist
    │ │   └─ Prerequisite: None (public + !revoked)
    │ │
    │ ├─ SkypierVPN.validateOperator(operator, peerId)
    │ │   └─ Prerequisite: VALIDATOR_ROLE (CRITICAL!)
    │ │   └─ Effect:
    │ │       ├─ nodes[operator] created
    │ │       └─ OperatorToken.mint(operator, nodeId)
    │ │
    │ └─ OperatorToken.mint(operator, nodeId) → tokenId
    │     └─ Prerequisite: MINTER_ROLE
    │     └─ Effect: balanceOf[operator][tokenId] = 1
    │
    └─┬─ VALIDATOR OPERATIONAL GATING
      └─ SkypierVPN.validateOperator(operator, peerId)
          └─ onlyRole(VALIDATOR_ROLE)
          └─ CANNOT be called without VALIDATOR_BADGE

Level 3: ROLE-SPECIFIC OPERATIONS
    │
    ├─┬─ BUILDER OPERATIONS (requires BUILDER_BADGE)
    │ ├─ EmployeeLevelBadge.mintEmployeeLevelBadge(employee, amount, customExpiry)
    │ │   └─ Prerequisite: BUILDER_BADGE holder + ADMIN_ROLE
    │ │   └─ Effect: EMPLOYEE_BADGE issued with 52-week expiry
    │ │
    │ ├─ AdminBadge.mintAdminBadge(newAdmin)
    │ │   └─ Prerequisite: BUILDER_BADGE holder + ADMIN_ROLE
    │ │   └─ Effect: newAdmin gets ADMIN_BADGE + DEFAULT_ADMIN_ROLE
    │ │
    │ └─ PaymentPool operations (via delegated PAYMENT_MANAGER)
    │     └─ setPaymentAmount(), setWallets(), distributePayments()
    │
    ├─┬─ OPERATOR OPERATIONS (requires OPERATOR_TOKEN)
    │ ├─ SkypierVPN.heartbeat(operator)
    │ │   └─ Expected: Periodic calls from operator
    │ │   └─ Effect: nodes[operator].lastHeartbeat = block.timestamp
    │ │
    │ └─ PaymentPool operator rewards (automated)
    │     └─ distributePayments() loops through operators[*]
    │     └─ Sends earnings if isActive
    │
    ├─┬─ VALIDATOR OPERATIONS (requires VALIDATOR_BADGE)
    │ ├─ SkypierVPN.validateOperator(operator, peerId) ← ONLY VALIDATOR CAN DO THIS
    │ │   └─ Effect: Moves operator from WAITLIST to ACTIVE
    │ │   └─ Consequence: Network security depends on validator quality
    │ │
    │ └─ PaymentPool validator rewards (automated)
    │     └─ distributePayments() loops through validators[*]
    │     └─ Sends earnings for validation work
    │
    ├─┬─ CLIENT OPERATIONS (requires CLIENT_BADGE)
    │ ├─ SkypierVPN node connection [off-chain gateway]
    │ │   └─ Gateway checks: balanceOf(client, CLIENT_BADGE) > 0 && !isExpired()
    │ │   └─ If true: Allow connection
    │ │   └─ If false: Deny connection
    │ │
    │ └─ Renewal: PaymentPool.deposit() → ClientToken.mint() again
    │
    ├─┬─ EMPLOYEE_BADGE OPERATIONS
    │ └─ (Badge holder) Access benefits tied to badge
    │     └─ Expiration: burnExpiredBadges() revokes automatically
    │
    ├─┬─ BETA_TESTER OPERATIONS
    │ ├─ SkypierBadges.balanceOf(tester, BETA_TESTER_BADGE_ID)
    │ │   └─ Return > 0: Early feature access enabled
    │ │
    │ └─ Off-chain: Apply special rate/feature access
    │
    └─┬─ PROJECT_SPONSOR_BADGE OPERATIONS
      ├─ ProjectSponsorBadge.getProjectInfo(tokenId)
      │   └─ Returns: projectId, startTime, endTime, sponsor
      │
      ├─ ProjectSponsorBadge.isValidBadge(tokenId)
      │   └─ true if active and not expired
      │
      └─ (Sponsor) Receive benefits tied to project
          └─ Community recognition, preferential terms, etc.
```

### Critical Dependency: VALIDATOR_ROLE

```
OPERATOR CANNOT BECOME ACTIVE WITHOUT:
    ├─ Step 1: Someone holds VALIDATOR_BADGE
    ├─ Step 2: VALIDATOR calls SkypierVPN.validateOperator(operator, peerId)
    ├─ Step 3: Only then: nodes[operator] created & OperatorToken minted
    │
    └─ FAILURE CASE: If no validators exist
        ├─ applyAsOperator() succeeds (operator added to waitlist)
        ├─ validateOperator() can NEVER be called
        ├─ Operator remains in WAITLIST forever
        └─ Operator cannot be activated
```

**Mitigation:** System must ensure at least 1 validator exists at all times.

### Critical Dependency: BUILDER_BADGE → ADMIN_BADGE → BUILDER Recursion

```
PROBLEM: To grant first BUILDER_BADGE, admin needs ADMIN_ROLE
         To grant first ADMIN_BADGE, caller needs BUILDER_BADGE
         → CIRCULAR DEPENDENCY

SOLUTION: Bootstrap via initialize()
├─ AdminBadge.initialize(uri, builderToken, BUILDER_BADGE_ID, admin)
│   └─ _grantRole(DEFAULT_ADMIN_ROLE, admin)  ← Initial admin granted here
│
└─ First admin can then:
   ├─ mintBuilderToken(builderAddress)
   └─ mintAdminBadge(newAdminAddress)
```

---

## Function Flow Diagrams

### DIAGRAM 1: End-to-End Client Journey

```
CLIENT PERSONA: Full VPN Access Lifecycle

START
  │
  ├─→ [User] Has ETH or stablecoins
  │
  ├─→ PaymentPool.deposit() ──CALL──→ 
  │   ├── Validates: msg.value >= paymentAmount
  │   ├── Records: totalClientDeposits += msg.value
  │   ├── Event: ClientDeposit(msg.sender, msg.value)
  │   └── (Off-chain relayer triggers mint)
  │
  ├─→ ClientToken.mint(user, CLIENT_BADGE, 1, metadata) ──CALL──→
  │   ├── Validates: MINTER_ROLE
  │   ├── Creates: balances[user][CLIENT_BADGE] = 1
  │   ├── Sets: expiries[tokenId] = T + duration
  │   ├── Soulbound: No transfers allowed
  │   └── Event: BadgeIssued(user, CLIENT_BADGE, 1, metadata)
  │
  ├─→ [User can now access VPN] ──OFF-CHAIN──→
  │   ├── Connects to node
  │   ├── Gateway checks: balanceOf(user, CLIENT_BADGE) > 0
  │   ├── Checks: !isExpired(tokenId)
  │   └── Connection granted if both true
  │
  ├─→ [After duration expires or manual revocation]
  │
  ├─→ ClientToken.burn(user, CLIENT_BADGE, 1) ──CALL──→
  │   ├── Validates: BURNER_ROLE
  │   ├── Destroys: balances[user][CLIENT_BADGE] = 0
  │   ├── Event: BadgeRevoked(user, CLIENT_BADGE, 1)
  │   └── (Off-chain gateway detects balance = 0)
  │
  ├─→ [VPN access automatically denied]
  │
  ├─→ [User can renew via new deposit]
  │
  └─→ (Loop back to deposit or END)

KEY DEPENDENCIES:
  ├─ PaymentPool MUST be initialized
  ├─ ClientToken MUST have MINTER_ROLE assigned to relayer
  ├─ paymentAmount MUST be set (via setPaymentAmount())
  └─ ExpiryManagement library MUST track token expiry
```

### DIAGRAM 2: End-to-End Operator Journey

```
OPERATOR PERSONA: Node Registration & Operation

START
  │
  ├─→ [Prospective operator] Wants to run node
  │
  ├─→ SkypierVPN.applyAsOperator(peerId) ──CALL──→
  │   ├── Validates: !revokedOperators[msg.sender]
  │   ├── Validates: !nodes[msg.sender].isActive
  │   ├── Records: operatorPeerIds[msg.sender] = peerId
  │   ├── Adds: operatorWaitlist.push(msg.sender)
  │   └── Event: OperatorAddedToWaitlist(msg.sender)
  │
  ├─→ [System waits for validator approval]
  │
  ├─→ SkypierVPN.validateOperator(operator, peerId) ──CALL──→
  │   ├── Validates: onlyRole(VALIDATOR_ROLE) ← CRITICAL GATE
  │   ├── Validates: bytes(operatorPeerIds[operator]).length > 0
  │   ├── Creates: nodes[operator] = Node {owner, peerId, isActive, registeredAt, lastHeartbeat}
  │   ├─→ OperatorToken.mint(operator, peerId) ──CALL──→
  │   │   ├── Returns: tokenId (unique)
  │   │   ├── Creates: operatorInfo[tokenId] = OperatorInfo {nodeId, registeredAt, isActive}
  │   │   ├── Mints: _mint(operator, tokenId, 1, "")
  │   │   └── Event: OperatorRegistered(tokenId, peerId, operator)
  │   └── Event: NodeRegistered(operator, peerId)
  │
  ├─→ [Operator now ACTIVE, can run node]
  │
  ├─→ [Periodically: operator calls heartbeat]
  │   SkypierVPN.heartbeat(operatorAddress) ──CALL──→
  │   └── Updates: nodes[operator].lastHeartbeat = block.timestamp
  │
  ├─→ [Periodically: bi-weekly rewards]
  │   PaymentPool.distributePayments() ──CALL──→
  │   ├── For each operators[operatorAddress]:
  │   │   ├── If isActive && (lastPayment + BIOWEEKLY_INTERVAL <= now):
  │   │   │   ├── Calculate: operatorShare = totalPool / activeOperatorCount
  │   │   │   ├── Transfer: wallet.transfer(operatorShare)
  │   │   │   └── Update: lastPayment = block.timestamp
  │   │   └── totalNetworkPayments += operatorShare
  │   └── Event: PaymentDistributed(operator, operatorShare, "OPERATOR")
  │
  ├─→ [If operator breaches or exits]
  │   SkypierVPN.revokeOperator(operator) ──CALL──→
  │   ├── Validates: onlyRole(ADMIN_ROLE)
  │   ├── Sets: revokedOperators[operator] = true
  │   ├── Sets: nodes[operator].isActive = false
  │   ├─→ OperatorToken.deregisterOperator(tokenId) ──CALL──→
  │   │   ├── Sets: operatorInfo[tokenId].isActive = false
  │   │   └── Event: OperatorUnregistered(tokenId)
  │   └── Event: NodeRevoked(operator)
  │
  └─→ [Operator loses rewards & node access]

KEY DEPENDENCIES:
  ├─ VALIDATOR_ROLE MUST exist (critical gate at validateOperator)
  ├─ SkypierVPN MUST be initialized with correct PaymentPool & staking config
  ├─ PaymentPool MUST have operators[address] setup
  ├─ At least one VALIDATOR must exist for any operator to activate
  └─ Heartbeat tracking prevents reward to offline operators (off-chain policy)
```

### DIAGRAM 3: End-to-End Validator Journey

```
VALIDATOR PERSONA: Stake → Validate → Earn

START
  │
  ├─→ [Prospective validator] Has staking capital
  │
  ├─→ [Off-chain] Transfer staking tokens to contract
  │   ERC20.transfer(skypierAddress, stakingAmount)
  │   └── Prerequisite: Enough balance
  │
  ├─→ ValidatorToken.mintValidatorBadge(validatorAddress, stakingAmount) ──CALL──→
  │   ├── Validates: onlyRole(MINTER_ROLE)
  │   ├── Validates: stakingAmount > 0
  │   ├── Creates: validators[validatorAddress] = ValidatorInfo {
  │   │   ├── validatorAddress: address,
  │   │   ├── stakingAmount: uint256,
  │   │   ├── registeredAt: block.timestamp,
  │   │   └── isActive: true
  │   │ }
  │   ├── Mints: _mint(validatorAddress, VALIDATOR_BADGE, 1, "")
  │   ├── GRANTS: onlyRole(VALIDATOR_ROLE) via AccessControl
  │   └── Event: ValidatorRegistered(validatorAddress, stakingAmount)
  │
  ├─→ [Validator now has VALIDATOR_ROLE]
  │
  ├─→ [Validator reviews operator applications]
  │   SkypierVPN.operatorWaitlist ──READ──→
  │   └── Public array: [operator1, operator2, ...]
  │
  ├─→ [Validator approves operator]
  │   SkypierVPN.validateOperator(operator, peerId) ──CALL──→
  │   ├── Validates: onlyRole(VALIDATOR_ROLE) ← CAN ONLY CALL THIS
  │   ├── Moves: operator from WAITLIST → ACTIVE
  │   ├─→ OperatorToken.mint(operator, peerId) ──CALL──→
  │   │   └── Creates: New operator node registration
  │   └── Event: OperatorValidated(operator, peerId)
  │
  ├─→ [Periodically: validator earns rewards]
  │   PaymentPool.distributePayments() ──CALL──→
  │   ├── For each validators[validatorAddress]:
  │   │   ├── If isActive && (lastPayment + BIOWEEKLY_INTERVAL <= now):
  │   │   │   ├── Calculate: validatorShare = totalPool / activeValidatorCount
  │   │   │   ├── Transfer: wallet.transfer(validatorShare)
  │   │   │   └── Update: lastPayment = block.timestamp
  │   │   └── totalNetworkPayments += validatorShare
  │   └── Event: PaymentDistributed(validator, validatorShare, "VALIDATOR")
  │
  ├─→ [If validator misbehaves or exits]
  │   ValidatorToken.revokeValidatorBadge(validatorAddress) ──CALL──→
  │   ├── Validates: onlyRole(BURNER_ROLE)
  │   ├── Burns: _burn(validatorAddress, VALIDATOR_BADGE, 1)
  │   ├── Updates: validators[validatorAddress].isActive = false
  │   ├── REVOKES: VALIDATOR_ROLE (via AccessControl)
  │   └── Event: ValidatorDeregistered(validatorAddress)
  │
  ├─→ [Staking tokens returned to validator wallet]
  │   (Implementation detail: Not shown in current contracts)
  │
  └─→ [Validator loses validation authority & future rewards]

KEY DEPENDENCIES:
  ├─ ValidatorToken MUST be initialized
  ├─ MINTER_ROLE MUST be assigned to validator setup authority
  ├─ PaymentPool MUST track validators[address] struct
  ├─ Staking amount MUST exceed minimum (contract-defined)
  ├─ ExternalERC20 staking token MUST have sufficient balance
  └─ At least one validator needed for operators to activate (critical)
```

### DIAGRAM 4: Builder → Employee Badge Hierarchy

```
BUILDER PERSONA: Creating Employee Hierarchy

START
  │
  ├─→ [Admin grants BUILDER_BADGE]
  │   BuilderToken.mintBuilderToken(builderAddress) ──CALL──→
  │   ├── Validates: onlyRole(DEFAULT_ADMIN_ROLE)
  │   ├── Mints: _mint(builderAddress, BUILDER_BADGE, 1, "")
  │   └── Event: Builder now can manage employees
  │
  ├─→ [Builder initializes EmployeeLevelBadge contract]
  │   EmployeeLevelBadge.initialize(uri, builderToken, BUILDER_BADGE_ID, expiryDuration, admin)
  │   ├── Sets: self.builderToken = builderToken
  │   ├── Sets: self.builderTokenId = BUILDER_BADGE_ID (0)
  │   └── Sets: expiryDuration = 52 weeks (default)
  │
  ├─→ [Builder mints EMPLOYEE_BADGE for employee]
  │   EmployeeLevelBadge.mintEmployeeLevelBadge(employeeAddress, amount, customExpiryDuration) ──CALL──→
  │   ├── Validates: BUILDER_BADGE holder
  │   │   └── require(IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0)
  │   ├── Validates: DEFAULT_ADMIN_ROLE
  │   │   └── require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
  │   ├── Validates: amount <= WALLET_CAP (6)
  │   ├── Creates: uint256 tokenId = _nextTokenId++
  │   ├── Mints: _safeMintWithRole(employeeAddress, tokenId, amount, "")
  │   ├── Sets expiry:
  │   │   dur = customExpiryDuration > 0 ? customExpiryDuration : expiryDuration
  │   │   _expiry[tokenId] = {expiryTime: block.timestamp + dur, isActive: true}
  │   └── Event: BadgeExpired(tokenId, expiryTime)
  │
  ├─→ [Employee now has EMPLOYEE_BADGE for 52 weeks]
  │
  ├─→ [Employee benefits from badge for duration]
  │   (Application-dependent: Voting rights, discounts, etc.)
  │
  ├─→ [Builder can extend badge before expiry]
  │   EmployeeLevelBadge.extendExpiry(tokenId, additionalDuration) ──CALL──→
  │   ├── Validates: DEFAULT_ADMIN_ROLE
  │   ├── Updates: _expiry[tokenId].expiryTime += additionalDuration
  │   └── Event: ExpiryExtended(tokenId, newExpiryTime)
  │
  ├─→ [If badge expires or employee leaves]
  │   EmployeeLevelBadge.burnExpiredBadges(employeeAddress, tokenId) ──CALL──→
  │   ├── Validates: DEFAULT_ADMIN_ROLE
  │   ├── Validates: _expiry[tokenId].isExpired()
  │   ├── Burns: _safeBurnWithRole(employeeAddress, tokenId, 1)
  │   ├── Updates: _expiry[tokenId].isActive = false
  │   └── Event: Badge destroyed, employee loses benefits
  │
  └─→ [Repeat for new employees]

KEY DEPENDENCIES:
  ├─ BUILDER_BADGE MUST exist (prerequisite for employee badge management)
  ├─ BuilderToken contract MUST be set in EmployeeBadge.initialize()
  ├─ ExpiryManagement library MUST track token lifetimes
  ├─ Admin must call burnExpiredBadges() after expiry (no auto-burn)
  └─ Wallet cap enforced (max 6 badges per employee)
```

---

## End-to-End Workflows

### WORKFLOW 1: New System Initialization

```
PHASE 1: CONTRACT DEPLOYMENT
├─ Deploy BuilderToken
├─ Deploy ValidatorToken
├─ Deploy OperatorToken
├─ Deploy ClientToken
├─ Deploy SkypierToken (ERC20 base token)
├─ Deploy PaymentPool
├─ Deploy SkypierVPN
├─ Deploy EmployeeLevelBadge
├─ Deploy AdminBadge
├─ Deploy ProjectSponsorBadge
├─ Deploy SkypierBadges
├─ Deploy HumanResources
├─ Deploy NodeStatusContract
├─ Deploy NodeConfigContract
└─ Deploy ERC6551Registry (for TBA)

PHASE 2: INITIALIZATION IN DEPENDENCY ORDER
├─ BuilderToken.initialize()
│   └── _grantRole(DEFAULT_ADMIN_ROLE, deployer)
│
├─ ValidatorToken.initialize()
│   └── _grantRole(MINTER_ROLE, deployer)
│
├─ OperatorToken.initialize()
│   └── _grantRole(MINTER_ROLE, skypierVpnAddress)
│
├─ ClientToken.initialize(paymentPoolAddress, adminAddress)
│   └── _grantRole(MINTER_ROLE, paymentPoolAddress)
│
├─ SkypierVPN.initialize(
│     paymentPoolAddress,
│     operatorTokenAddress,
│     stakeAmount
│   )
│   └── _grantRole(VALIDATOR_ROLE, deployer) [initial]
│
├─ PaymentPool.initialize(
│     skypierTokenAddress,
│     clientTokenAddress,
│     usdcTokenAddress,
│     networkPool,
│     builderPool,
│     developerPool,
│     paymentAmount,
│     adminAddress
│   )
│   └── Sets initial payment amount & wallet addresses
│
├─ EmployeeLevelBadge.initialize(
│     uri,
│     builderTokenAddress,
│     BUILDER_BADGE_ID,
│     expiryDuration,
│     adminAddress
│   )
│   └── Links to BuilderToken for prerequisite checks
│
├─ AdminBadge.initialize(
│     uri,
│     builderTokenAddress,
│     BUILDER_BADGE_ID,
│     adminAddress
│   )
│   └── Links to BuilderToken for prerequisite checks
│
├─ ProjectSponsorBadge.initialize()
│   └── _grantRole(DEFAULT_ADMIN_ROLE, adminAddress)
│
├─ SkypierBadges.initialize()
│   └── _grantRole(MINTER_ROLE, adminAddress)
│
├─ HumanResources.initialize(builderPoolWalletAddress)
│   └── _grantRole(HR_MANAGER_ROLE, deployer)
│
└─ [...other contracts]

PHASE 3: BOOTSTRAP INITIAL ROLES
├─ SkypierVPN.setValidatorRole() / Manual setup
│   └── Ensure at least 1 VALIDATOR exists
│       ValidatorToken.mintValidatorBadge(validatorAddress, stakingAmount)
│
├─ BuilderToken.mintBuilderToken(builderAddresses)
│   └── Grant BUILDER role to initial team members
│       (Enables employee badge management)
│
├─ AdminBadge.mintAdminBadge(adminAddresses)
│   └── Grant additional ADMIN_ROLE holders if needed
│       (For distributed permission management)
│
└─ PaymentPool.setWallets(networkPool, builderPool, developerPool)
    └── Configure payment distribution destinations

PHASE 4: SYSTEM READINESS
├─ Verify:
│   ├─ ValidatorToken has at least 1 validator
│   ├─ BuilderToken has core team members
│   ├─ PaymentPool has funds allocated
│   └─ All minter/burner roles assigned
│
└─ System is LIVE and ready for users

CRITICAL ORDERING:
  1. BuilderToken MUST be deployed first (prerequisite for Admin/Employee badges)
  2. ValidatorToken BEFORE SkypierVPN (wallet validation needs validator)
  3. PaymentPool MUST be init before clients can deposit
  4. At least 1 VALIDATOR MUST exist before operators can activate
```

### WORKFLOW 2: First User Onboarding (All Personas)

```
SCENARIO: Day 1 of network launch

1. INITIAL SETUP (Admin)
   └─ Admin ensures all prerequisite roles exist
      ├─ VALIDATOR_BADGE issued to trusted validator
      ├─ BUILDER_BADGE issued to core team
      └─ ADMIN_BADGE issued to operations lead

2. FIRST CLIENT ARRIVES
   ├─ Client: PaymentPool.deposit() → {value: 10 ETH}
   ├─ PaymentPool: totalClientDeposits += 10 ETH
   ├─ Relayer: ClientToken.mint(client, CLIENT_BADGE, 1, metadata)
   ├─ VPN Gateway: balanceOf(client, CLIENT_BADGE) = 1 ✓
   └─ CLIENT can now access VPN

3. FIRST OPERATOR APPLIES
   ├─ Operator: SkypierVPN.applyAsOperator("QmXxxx...")
   ├─ SkypierVPN: operatorWaitlist.push(operator)
   ├─ System: Notifies validators (off-chain)

4. VALIDATOR APPROVES OPERATOR
   ├─ Validator: SkypierVPN.validateOperator(operator, "QmXxxx...")
   ├─ SkypierVPN: Creates nodes[operator] struct
   ├─ SkypierVPN: OperatorToken.mint(operator, "QmXxxx...") → tokenId
   ├─ OperatorToken: balanceOf[operator][tokenId] = 1
   └─ OPERATOR is now ACTIVE

5. FIRST PAYMENT DISTRIBUTION (Bi-weekly)
   ├─ PaymentPool: distributePayments()
   ├─ Distribute network payments to:
   │  ├─ operators[operator] → operatorShare
   │  ├─ validators[validator] → validatorShare
   │  └─ builders[builder] via HumanResources
   └─ All parties receive first earnings

6. FIRST EMPLOYEE BADGE ISSUANCE (Builder)
   ├─ Builder: EmployeeLevelBadge.mintEmployeeLevelBadge(employee, 1, 0)
   ├─ EmployeeLevelBadge: Creates tokenId, sets expiry = block.timestamp + 52 weeks
   ├─ Employee: balanceOf[employee][tokenId] = 1
   └─ EMPLOYEE receives benefits for 52-week tenure

7. FIRST BETA TESTER BADGE
   ├─ Admin: SkypierBadges.mintBadge(betaTester, BETA_TESTER_BADGE_ID, 1, metadata)
   ├─ SkypierBadges: _badgeAttributes[BETA_TESTER_BADGE_ID][betaTester] = {…}
   └─ BETA_TESTER gains early access to features

8. FIRST PROJECT SPONSOR
   ├─ Admin: ProjectSponsorBadge.mintSponsorBadge(sponsor, "Q2_EXPANSION", 0)
   ├─ ProjectSponsorBadge: tokenId = keccak256("Q2_EXPANSION", sponsor, now)
   ├─ ProjectSponsorBadge: _projectInfo[tokenId] = {projectId, startTime, endTime, sponsor}
   ├─ ProjectSponsorBadge: endTime = block.timestamp + 52 weeks
   └─ SPONSOR is now active for Q2 project

NETWORK STATUS AFTER DAY 1:
┌──────────────────────────────────────────┐
│ PERSONAS ACTIVE:                         │
├──────────────────────────────────────────┤
│ ✓ CLIENT_ROLE (1 user, paying)          │
│ ✓ OPERATOR_ROLE (1 active, earning)     │
│ ✓ VALIDATOR_ROLE (1 active, earning)    │
│ ✓ BUILDER_ROLE (1 managing employees)   │
│ ✓ EMPLOYEE_BADGE (1 user, 52w duration) │
│ ✓ ADMIN_BADGE (1 operations lead)       │
│ ✓ BETA_TESTER_BADGE (1 early access)    │
│ ✓ PROJECT_SPONSOR_BADGE (1, Q2 proj)    │
├──────────────────────────────────────────┤
│ TOTAL ACTIVE PERSONAS: 8                 │
│ Network Status: OPERATIONAL ✓             │
└──────────────────────────────────────────┘
```

---

## Role Hierarchy & Prerequisites

### Prerequisite Chain Diagram

```
╔════════════════════════════════════════════════════════════════════════════════╗
║                         ROLE HIERARCHY & DEPENDENCIES                          ║
╚════════════════════════════════════════════════════════════════════════════════╝

LEVEL 0: BOOTSTRAP (SYSTEM)
┌────────────────────────────────────────────────────────────────┐
│ DEFAULT_ADMIN_ROLE                                             │
│ ├─ Granted at contract initialization                          │
│ ├─ Can grant/revoke all other roles                            │
│ └─ Can authorize contract upgrades (via UUPS)                  │
└────────────────────────────────────────────────────────────────┘
                         │
                         │ grants (only)
                         ↓
LEVEL 1: CORE INFRASTRUCTURE
┌────────────────────────────────────────────────────────────────┐
│ BUILDER_ROLE ◄──────────────────────────────────────────────┬──┤
│ ├─ Prerequisite: MUST be granted by DEFAULT_ADMIN_ROLE     │  │
│ ├─ Via: BuilderToken.mintBuilderToken(address)             │  │
│ ├─ Enables:                                                  │  │
│ │  ├─ Create EMPLOYEE_BADGE                                 │  │
│ │  ├─ Create ADMIN_BADGE                                    │  │
│ │  └─ Manage payment parameters (via PAYMENT_MANAGER)       │  │
│ └─ Token Type: ERC1155 soulbound, BUILDER_BADGE_ID=0        │  │
│                                                              │  │
│ VALIDATOR_ROLE ◄──────────────────────────────────────────┐ │  │
│ ├─ Prerequisite: Staking required                         │ │  │
│ ├─ Via: ValidatorToken.mintValidatorBadge(address, stake) │ │  │
│ ├─ Enables:                                                │ │  │
│ │  ├─ Validate operator applications [CRITICAL]           │ │  │
│ │  └─ Earn validator rewards (bi-weekly)                  │ │  │
│ └─ Token Type: ERC1155 soulbound, VALIDATOR_BADGE_ID=3   │ │  │
└────────────────────────────────────────────────────────────┼──┘
                         │                                   │
         ┌───────────────┴─────────────────┬──────────────────┘
         │                                 │
      DEPENDS ONBUILDER to manage employees
      DEPENDS ON VALIDATOR to activate operators
         │                                 │
         ↓                                 ↓
LEVEL 2: USER-FACING ROLES
┌────────────────────────────────────────────────────────────────┐
│ CLIENT_ROLE                                                    │
│ ├─ Prerequisite: Payment deposit to PaymentPool              │
│ ├─ Via: PaymentPool.deposit() + ClientToken.mint()           │
│ ├─ Enables: VPN access (soulbound token check)               │
│ ├─ Duration: Customizable (typically 30 days)                │
│ └─ Token: ClientToken (ERC1155), CLIENT_BADGE_ID=0           │
│                                                              │
│ OPERATOR_ROLE                                                │
│ ├─ Prerequisites:                                            │
│ │  ├─ Apply via SkypierVPN.applyAsOperator()               │
│ │  ├─ VALIDATOR approval [CRITICAL GATE]                   │
│ │  └─ Not previously revoked                                │
│ ├─ Via: SkypierVPN.validateOperator() [VALIDATOR-only]      │
│ │   → OperatorToken.mint(operator, nodeId)                  │
│ ├─ Enables:                                                 │
│ │  ├─ Run VPN node (operator account)                       │
│ │  ├─ Earn operator rewards (bi-weekly)                     │
│ │  └─ Periodic heartbeat to stay active                     │
│ └─ Token: OperatorToken (ERC1155), unique tokenId per node  │
│                                                              │
│ EMPLOYEE_BADGE                                              │
│ ├─ Prerequisite: BUILDER_BADGE holder must grant            │
│ ├─ Via: EmployeeLevelBadge.mintEmployeeLevelBadge()         │
│ ├─ Duration: 52 weeks (customizable on mint)                │
│ ├─ Enables: Employee benefits, voting, etc.                 │
│ └─ Token: EmployeeLevelBadge (ERC1155), EMPLOYEE_BADGE_ID=5 │
│                                                              │
│ BETA_TESTER_BADGE                                           │
│ ├─ Prerequisite: Admin/MINTER grant (optional)              │
│ ├─ Via: SkypierBadges.mintBadge()                           │
│ ├─ Enables: Early feature access                            │
│ └─ Token: SkypierBadges (ERC1155), BETA_TESTER_BADGE_ID=6   │
│                                                              │
│ PROJECT_SPONSOR_BADGE                                       │
│ ├─ Prerequisite: Admin grant only                           │
│ ├─ Via: ProjectSponsorBadge.mintSponsorBadge()              │
│ ├─ Duration: Fixed 52 weeks                                 │
│ ├─ Enables: Project recognition, sponsor benefits           │
│ └─ Token: ProjectSponsorBadge (ERC1155), SPONSOR_BADGE_ID=7 │
└────────────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┴─────────────────┐
         │ requires admin approval         │ requires validator approval
         │                                 │
         ↓                                 ↓
LEVEL 3: TOP-LEVEL ADMINISTRATIVE
┌────────────────────────────────────────────────────────────────┐
│ ADMIN_BADGE (combines both)                                    │
│ ├─ Prerequisite: BUILDER + existing ADMIN                      │
│ ├─ Via: AdminBadge.mintAdminBadge(address)                     │
│ ├─ Enables: Full system access (all admin functions)           │
│ ├─ Dual nature:                                                │
│ │  ├─ ERC1155 token (soulbound)                               │
│ │  └─ Grants DEFAULT_ADMIN_ROLE in AccessControl             │
│ └─ Token: AdminBadge (ERC1155), ADMIN_BADGE_ID=0              │
│                                                              │
│ ADMIN_ROLE CAPABILITIES:                                      │
│ ├─ Grant other roles (role-holder)                            │
│ ├─ Revoke roles                                               │
│ ├─ Authorize contract upgrades                                │
│ ├─ Pause/unpause tokens                                       │
│ ├─ Manage all parameters                                      │
│ ├─ Emergency actions                                          │
│ └─ Delegate to sub-roles:                                     │
│    ├─ MINTER_ROLE (badge creation)                           │
│    ├─ BURNER_ROLE (badge revocation)                         │
│    ├─ PAUSER_ROLE (emergency freeze)                         │
│    ├─ PAYMENT_MANAGER (distribution)                         │
│    └─ HR_MANAGER_ROLE (employee setup)                       │
└────────────────────────────────────────────────────────────────┘

CRITICAL GATES:
  1. NO OPERATOR can activate without VALIDATOR approval
  2. NO ADMIN can be created without BUILDER holding token
  3. NO EMPLOYEE can be managed without BUILDER token
  4. Bootstrap: First admin granted at initialization

SINGLE POINTS OF FAILURE:
  ├─ If no VALIDATOR exists → Operators cannot activate
  ├─ If ADMIN is compromised → All system access compromised
  └─ If all BOUDLERs deactivated → No new employees can be added
```

### Permission Matrix

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                      FUNCTION ACCESS CONTROL MATRIX                            │
├─────────────────────────┬──────────┬──────────┬──────────┬──────────┬──────────┤
│ FUNCTION                │ ADMIN    │ BUILDER  │ CLIENT   │ OPERATOR │ VALIDATOR│
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ BuilderToken.mintBuilderToken    │ ✓        │          │          │          │          │
│ AdminBadge.mintAdminBadge        │ ✓        │ ✓        │          │          │          │
│ AdminBadge.burnAdminBadge        │ ✓        │          │          │          │          │
│ EmployeeLevelBadge.mintEmployee  │ ✓        │ ✓        │          │          │          │
│ EmployeeLevelBadge.burnExpired   │ ✓        │          │          │          │          │
│ EmployeeLevelBadge.extendExpiry  │ ✓        │          │          │          │          │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ ValidatorToken.mintValidator     │ ✓        │          │          │          │          │
│ ValidatorToken.revokeValidator   │ ✓        │          │          │          │          │
│ SkypierVPN.validateOperator      │          │          │          │          │ ✓        │
│ SkypierVPN.applyAsOperator       │          │          │          │ ✓        │          │
│ SkypierVPN.revokeOperator        │ ✓        │          │          │          │          │
│ SkypierVPN.heartbeat             │          │          │          │ ✓        │          │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ PaymentPool.deposit              │          │          │ ~✓       │          │          │
│ PaymentPool.setPaymentAmount     │ ✓        │ ✓        │          │          │          │
│ PaymentPool.distributePayments   │ ✓        │ ✓        │          │          │          │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ ClientToken.mint                 │ ✓        │          │          │          │          │
│ ClientToken.burn                 │ ✓        │          │          │          │          │
│ ClientToken.setExpiry            │ ✓        │          │          │          │          │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ ProjectSponsorBadge.mintSponsor  │ ✓        │          │          │          │          │
│ ProjectSponsorBadge.getProjectInfo│ ✓       │ ✓        │ ~✓       │ ~✓       │ ~✓       │
│ ProjectSponsorBadge.isValidBadge │ ✓        │ ✓        │ ~✓       │ ~✓       │ ~✓       │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ SkypierBadges.mintBadge          │ ✓        │ ✓        │          │          │          │
│ SkypierBadges.revokeBadge        │ ✓        │ ✓        │          │          │          │
├─────────────────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ HumanResources.registerBuilder   │ ✓        │          │          │          │          │
│ HumanResources.processPayment    │ ✓        │          │          │          │          │
│ HumanResources.updateAllocation  │ ✓        │          │          │          │          │
└─────────────────────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

LEGEND:
  ✓   = Direct permission (via role or token)
  ~✓  = View-only permission (read state, not modify)
  [blank] = No permission
  
NOTES:
  • CLIENT can deposit() to initiate token mint (public function)
  • VALIDATOR is the ONLY role that can activate operators (critical gate)
  • Admin permissions inherit from DEFAULT_ADMIN_ROLE
  • Builder permissions require BUILDER_BADGE token holding
```

---

## Summary

This comprehensive analysis maps **8 distinct personas** across the Skypier ecosystem:

| Persona | Primary Function | Token Duration | Critical Gate | Dependency |
|---------|---|---|---|---|
| **CLIENT** | VPN access via payment | Variable | Payment amount | PaymentPool |
| **OPERATOR** | Node provisioning & earning | Indefinite | VALIDATOR approval | ValidatorToken |
| **VALIDATOR** | Operator validation & staking | Indefinite | Staking capital | Stake deposit |
| **BUILDER** | System parameters & employee mgmt | Indefinite | Admin grant | ADMIN_BADGE |
| **EMPLOYEE** | Performance tracking | 52 weeks | BUILDER grant | EmployeeBadge |
| **ADMIN** | Full system control | Indefinite | BUILDER + ADMIN | AdminBadge |
| **BETA_TESTER** | Early feature access | Optional | Minter discretion | SkypierBadges |
| **PROJECT_SPONSOR** | Project sponsorship tracking | 52 weeks | Admin grant | ProjectSponsorBadge |

**Key Architectural Principles:**
1. **Soulbound tokens** enforce role non-transferability
2. **Prerequisite dependencies** create role hierarchy
3. **VALIDATOR_ROLE is critical** (single point of failure for operator activation)
4. **Expiry management** enables time-limited roles (badges)
5. **Bi-weekly payments** distribute rewards across all earning roles
6. **Dual roles** (token + AccessControl) for admins and builders

---

**END OF ANALYSIS**
