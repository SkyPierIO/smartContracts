For **Solidity unit testing**, it's enabled from remix's plugin. 

# **Skypier Smart Contract Architecture - Product Requirement Document**

**Version:** 1.1  **Last Updated:** 2026-09-07

---

## **1. Overview**

This document outlines the requirements for restructuring Skypier’s smart contracts into **three distinct sets** with customizable layers:

1. **Product Deployment Contracts** (Customer-facing)
2. **Internal Development Contracts** (Team-facing)
3. **Community DAO Contracts** (Decentralized governance)

```bash
contracts/
├── interfaces/                    # Shared interfaces
│   ├── IAccessControl.sol         # Access control (roles, permissions)
│   ├── IBadges.sol                # Badge-related interfaces
│   ├── IPaymentPool.sol           # Payment pool interactions
│   ├── ISkypierVPN.sol            # VPN node operations
│   ├── ITokenBoundAccount.sol     # ERC-6551 TokenBoundAccount
│   └── IERC6551Registry.sol       # ERC-6551 registry
│
├── lib/                           # Shared libraries
│   ├── TokenBoundAccount.sol      # ERC-6551 implementation
│   └── ERC6551Registry.sol        # ERC-6551 registry
│
├── product/                       # Product Deployment Contracts (Customer-facing)
│   ├── tokens/
│   │   ├── SkypierToken.sol       # ERC-20 (updated for token gating)
│   │   └── SkypierBadges.sol      # ERC-1155 (Client, Operator, Validator)
│   ├── SkypierVPN.sol             # Node onboarding (updated roles)
│   ├── PaymentPool.sol            # Payment distribution (updated logic)
│   └── custom/                    # Customizable deployment layer (future)
│       └── CustomDeployment.sol   # Placeholder for deployment customization
│
├── internal/                      # Internal Development Contracts (Team-facing)
│   ├── tokens/
│   │   ├── BuilderToken.sol       # ERC-1155 (Builder role + Employee Badge)
│   │   ├── InvestorToken.sol      # ERC-1155 (Investor access)
│   │   ├── EmployeeBadge.sol      # ERC-1155 (Employee role badge)
│   │   ├── AdminBadge.sol         # ERC-1155 (Admin role badge)
│   │   └── AnnualizedBadges.sol   # ERC-1155-SFT (recognition badges)
│   ├── InternalDAO.sol            # Internal governance (placeholder)
│   └── HumanResources.sol         # Builder pool management
│
└── community/                     # Community DAO Contracts
    ├── CommunityDAO.sol           # Community governance (placeholder)
    └── ProjectSponsorBadge.sol    # Supplementary project sponsorship asset
```

---

## **2. Objectives**

- **Modularity:** Separate contracts for different stakeholders.
- **Token Gating:** Role-based access control via ERC-1155, ERC-6551, and Soulbound Tokens.
- **Upgradeability:** UUPS proxy pattern for all contracts.
- **Payment Distribution:** Automated biweekly payouts via `Payment Pool`.
- **DAO Governance:** Two-stage voting (Approval → Quadratic) for Community & Internal DAOs.

### Canonical product decisions

- Every persona is represented by an ERC-1155 role badge. Role hashes and canonical role IDs are defined in `contracts/lib/Roles.sol`.
- ERC-20, ERC-721, and ERC-3525 assets are supplementary capabilities; they do not replace ERC-1155 persona identity.
- Client access uses ERC-20 payment through `PaymentPool.payForAccess()`, which calls `ClientToken.mint()` after successful payment.
- `PaymentPool.deposit()` accepts ETH for pool funding and does not itself grant client access.
- Validator stake is held in a dedicated escrow contract. Escrow owns custody and controls release, refund, and slashing transitions.
- `CommunityDAO.sol` and `InternalDAO.sol` are placeholders for external DAO integrations until the external ABI and voting asset are selected.

---

## **3. Contract Architecture**

### **3.1. Product Deployment Contracts (Customer-Facing)**

**Purpose:** Handle user-facing operations (subscriptions, node validation & operation, payments).

### **Contracts:**

**Key Contracts**:

- **Tokens**:
    - `SkypierToken.sol` (ERC-20): Utility token for payments and network DAO Stage 2 Voting.
    - SkypierBadge (ERC1155 + ERC6551) – Role-based badges (Client, Operator, Validator)?
        - `SkypierBadges.sol` (ERC-1155): Supplementary beta and achievement badges.
        - `ClientToken.sol` (ERC-1155): Client role badge issued after ERC-20 payment.
        - `OperatorToken.sol` (ERC-1155): Supplementary operator asset for node hosts.
        - `ValidatorToken.sol` (ERC-1155): Supplementary validator asset for approved validators.
- **Core Logic**:
    - `SkypierVPN.sol`: Node onboarding/validation /offboarding (update to use `OperatorToken`/`ValidatorToken`).
    - `PaymentPool.sol`: Split payments into:
        - `Wallet(Network Pool)`: Manages customer payments and operator/validator biweekly payouts.
        - `Wallet(Builder Pool)`: Funds builder and employee allocations through `HumanResources.sol`.
    - `ValidatorEscrow.sol`: Planned UUPS contract for validator stake custody, release, refund, and slashing.
    - `nodeStatus.sol`/`nodeConfig.sol`: Move to `lib/` as shared utilities.
- **Custom Layer**:
    - `CustomDeployment.sol`: Placeholder for deployment-specific logic (e.g., regional compliance).

---

### **3.2. Internal Development Contracts (Team-Facing)**

**Purpose:** Manage employee operations, contributions, and internal governance.

### **Contracts:**

- **Tokens**:
    - `BuilderToken.sol` (ERC-1155): Canonical builder role badge and prerequisite for internal badges.
        - Can have `DEVELOPER_BADGE`
    - `InvestorToken.sol` (ERC-1155): For investors (non-transferable).
    - `EmployeeBadge.sol` (ERC-1155): Employee role badge with configurable expiry and builder-pool eligibility.
    - `AdminBadge.sol` (ERC-1155): Admin role badge controlled by the configured governance authority.
    - `AnnualizedBadges.sol` (ERC-1155-SFT): Recognition badges (e.g., `Mentor Badge`, `Trailblazer Badge`) & 52-week expiry .
- **Core Logic**:
    - `InternalDAO.sol`: Placeholder adapter for an external internal DAO.
    - `HumanResources.sol`:
        - Manages `BuilderToken` issuance/revocation.
        - Distributes `Wallet(Builder Pool)` funds biweekly based on `Employee Badge`.
        - Mints `AnnualizedBadges` via peer recognition (top 3 holders per category).

---

### **3.3. Community DAO Contracts (Decentralized Governance)**

**Purpose:** Enable Community stakeholder-driven proposals, voting on features & priorities, and project sponsorship.

### **Contracts:**

- **Tokens**:
    - `ProjectSponsorBadge.sol`: Supplementary project asset for project managers; expires 52 weeks post-delivery.
- **Core Logic**:
    - `CommunityDAO.sol`: **External DAO integration placeholder**
        - **Two-Stage Voting**: Approval (1 Wallet = 1 vote) → Quadratic voting (sqrt(NFT) vote).
        - `ProjectSponsorBadge`: Anyone who proposed or sponsored an accepted project can receive the supplementary project asset.
            - Earn yield for 52 weeks post-delivery.
    - **TokenBound Accounts (ERC-6551)**:
        - Use `TokenBoundAccount.sol` to attach badges (e.g., `ProjectSponsorBadge`) to wallets.

---

### **3.4. Shared Infrastructure**

### **A. Interfaces (`contracts/interfaces/`)**

- **New Interfaces**:
    - `IBadges.sol`: Standardize badge interactions (mint/revoke/check expiry).
    - `IPaymentPool.sol`: Define access payment, participant registration, contribution tracking, biweekly payout, and fund splitting.
- **Existing Interfaces**:
    - `IERC6551Registry.sol`/`ITokenBoundAccount.sol`: For badge-wallet linking.

### **B. Libraries (`contracts/lib/`)**

- **ERC-6551**:
    - `TokenBoundAccount.sol`: Manage accounts tied to badges (e.g., `ProjectSponsorBadge`).
    - `ERC6551Registry.sol`: Registry for TokenBoundAccounts.
- **Utilities**:
    - Move `nodeStatus.sol`/`nodeConfig.sol` here for shared use.

---

## **4. Token Requirements**

| Name | Token Standard | Purpose & definition | How to get this | **Expiry** (ERC-7818) | Max Allowed  | Transferable (ERC-1238) | Soulbound (ERC-5114) | Attributes | Parent Token |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `Client role badge`  | ERC1155 | Product Deployment Contracts — Customer access | ERC-20 payment → `PaymentPool.payForAccess()` → `ClientToken.mint()` | Configurable | One active role | No | Client identity and expiry | N/A |
| `Operator role badge` | ERC1155 | Product Deployment Contracts — Node hosting | `applyAsOperator()` → validator approval → `claimOperatorNFTBadge()` | No expiration | One active role | No | Operator identity, peer ID, active status | N/A |
| `Validator role badge`  | ERC1155 | Product Deployment Contracts — Node validation | Escrow-backed `applyAsValidator()` → approval → `claimValidatorNFTBadge()` | No expiration | One active role | No | Validator identity, stake, active status | N/A |
| `Builder role badge`  | ERC1155 | Internal Development Contracts — Builder identity | Admin/bootstrap issuance | Deployment policy | Deployment policy | No | Builder identity and active status | N/A |
| `Investor Token`  | ERC1155 | Internal Development Contract — Investor access | ClaimInvestorNFTBadge()  | Preset  | N/A | Multisig | False | EthAddr address, AddedBy address, ActiveSince timestamp | N/A |
| `Beta Tester Badge`  | ERC1155-SFT | Pre-release access | Issue by `Employee Badge` | Inherited | 1 | Inherited | Inherited | Inherited | `Client (Customer) Token`  |
| `Employee role badge`  | ERC1155 | Employee access and internal work | Builder/admin issuance | Configurable | Wallet policy | No | Employee identity and expiry | `Builder Token`  |
| `Developer supplementary badge`  | ERC1155 | Internal developer capability | Issue by governance | Deployment policy | Policy-defined | Policy-defined | Supplementary capability | `Builder Token`  |
| `Admin role badge`  | ERC1155 | Administrative identity | Employee/builder governance | No expiration | Deployment policy | No | Admin identity and access | `Employee role badge`  |
| `Annualized Badges` | ERC1155-SFT | Recognition (MVP, Mentor, etc.) | Reward from recognition  | Expires in 52 weeks | 1 per type | Inherited | Inherited | Inherited | `Builder Token`  |
| `Project Sponsor Badge` | Supplementary asset | Someone who proposed or sponsored an accepted project/issue | External DAO approval and project sponsorship | Expires in 52 weeks after accepting delivery | Project policy | Policy-defined | Supplementary capability | Applicable role badge |
| `Proof of Identity Badge` | ERC721 | Proof of humanity and identity | TBD | No expiration | 1 | Multisig | True | Inherited | Applicable all Non-badge ERC1155 tokens |
| `Skypier Token` | ERC20 | Vote and use the network | Purchase | No expiration | No Limit | True | False | N/A | N/A |

---

## **5. Payment Flow**

1. **Customers** → Approve ERC-20 payment and call `PaymentPool.payForAccess()`, which mints the client role badge.
2. **Operators** → Report metrics and receive eligible biweekly payouts from `Network Pool`.
3. **Validators** → Validate operators and receive eligible biweekly payouts from `Network Pool`.
4. **Builders and employees** → Receive allocation-based biweekly payouts from `Builder Pool` through `HumanResources`.
5. **Validator stake** → Enters `ValidatorEscrow`; release, refund, and slashing are escrow-controlled transitions.
6. **Investors** → ROI remains deferred until a separate treasury/accounting specification is approved.

---

## **6. DAO Governance**

| **DAO** | **Purpose** | **Voting Mechanism** |
| --- | --- | --- |
| **Community DAO** | Feature prioritization through an external DAO integration | Approval → Quadratic |
| **Internal DAO** | Employee equity and culture through an external DAO integration | Approval → Quadratic |




