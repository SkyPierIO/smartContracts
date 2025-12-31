For **Solidity unit testing**, it's enabled from remix's plugin. 

# **Skypier Smart Contract Architecture - Product Requirement Document**

**Version:** 1.0 **Last Updated:** [12/25/2025]

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
│   │   ├── EmployeeBadge.sol      # ERC-20 (rewards)
│   │   ├── AdminBadge.sol         # ERC-721 (Admin role)
│   │   └── AnnualizedBadges.sol   # ERC-1155-SFT (recognition badges)
│   ├── InternalDAO.sol            # Internal governance (placeholder)
│   └── HumanResources.sol         # Builder pool management
│
└── community/                     # Community DAO Contracts
    ├── CommunityDAO.sol           # Community governance (placeholder)
    └── ProjectSponsorBadge.sol    # ERC-3525 (project sponsorship)
```

---

## **2. Objectives**

- **Modularity:** Separate contracts for different stakeholders.
- **Token Gating:** Role-based access control via ERC-1155, ERC-6551, and Soulbound Tokens.
- **Upgradeability:** UUPS proxy pattern for all contracts.
- **Payment Distribution:** Automated biweekly payouts via `Payment Pool`.
- **DAO Governance:** Two-stage voting (Approval → Quadratic) for Community & Internal DAOs.

---

## **3. Contract Architecture**

### **3.1. Product Deployment Contracts (Customer-Facing)**

**Purpose:** Handle user-facing operations (subscriptions, node validation & operation, payments).

### **Contracts:**

**Key Contracts**:

- **Tokens**:
    - `SkypierToken.sol` (ERC-20): Utility token for payments and network DAO Stage 2 Voting.
    - SkypierBadge (ERC1155 + ERC6551) – Role-based badges (Client, Operator, Validator)?
        - `SkypierBadges.sol` (ERC-1155): Includes `Beta Tester Badge` (semi-fungible, transferable via multisig).
        - `ClientToken.sol` (ERC-1155): Auto-issued to customers after payment.
        - `OperatorToken.sol` (ERC-1155): For node hosts (non-transferable).
        - `ValidatorToken.sol` (ERC-1155): For node validators (non-transferable).
- **Core Logic**:
    - `SkypierVPN.sol`: Node onboarding/validation /offboarding (update to use `OperatorToken`/`ValidatorToken`).
    - `PaymentPool.sol`: Split payments into:
        - `Wallet(Network Pool)`: For Manages customer payments & operators/validators (biweekly payouts).
        - `Wallet(Builder Pool)`: For builders/investors (via `HumanResources.sol`).
    - `nodeStatus.sol`/`nodeConfig.sol`: Move to `lib/` as shared utilities.
- **Custom Layer**:
    - `CustomDeployment.sol`: Placeholder for deployment-specific logic (e.g., regional compliance).

---

### **3.2. Internal Development Contracts (Team-Facing)**

**Purpose:** Manage employee operations, contributions, and internal governance.

### **Contracts:**

- **Tokens**:
    - `BuilderToken.sol` (ERC-1155 + ERC-5114): Soulbound, holds up to 6 `EMPLOYEE_BADGE`a
        - Can have `DEVELOPER_BADGE`
    - `InvestorToken.sol` (ERC-1155): For investors (non-transferable).
    - `EmployeeBadge.sol` (ERC-20):
        - No expiry by default and expires after 78 weeks when the person leaves Skypier, expiry by `AdminBadge`.
        - 6 max → Biweekly payouts from `Builder Pool`.
    - `AdminBadge.sol` (ERC-721): Multisig-controlled (Clement & Ting).
    - `AnnualizedBadges.sol` (ERC-1155-SFT): Recognition badges (e.g., `Mentor Badge`, `Trailblazer Badge`) & 52-week expiry .
- **Core Logic**:
    - `InternalDAO.sol`: Placeholder for internal governance (e.g., OZ Governor, snapshot voting).
    - `HumanResources.sol`:
        - Manages `BuilderToken` issuance/revocation.
        - Distributes `Wallet(Builder Pool)` funds biweekly based on `Employee Badge`.
        - Mints `AnnualizedBadges` via peer recognition (top 3 holders per category).

---

### **3.3. Community DAO Contracts (Decentralized Governance)**

**Purpose:** Enable Community stakeholder-driven proposals, voting on features & priorities, and project sponsorship.

### **Contracts:**

- **Tokens**:
    - `ProjectSponsorBadge.sol` (ERC-3525): For project managers (expires 52 weeks post-delivery).
- **Core Logic**:
    - `CommunityDAO.sol`: **(Placeholder)**
        - **Two-Stage Voting**: Approval (1 Wallet = 1 vote) → Quadratic voting (sqrt(NFT) vote).
        - `ProjectSponsorBadge` **(ERC3525-SFT)** : Anyone who proposed an accepted project/issue or sponsored an accepted project gets `ProjectSponsorBadge`.
            - Earn yield for 52 weeks post-delivery.
    - **TokenBound Accounts (ERC-6551)**:
        - Use `TokenBoundAccount.sol` to attach badges (e.g., `ProjectSponsorBadge`) to wallets.

---

### **3.4. Shared Infrastructure**

### **A. Interfaces (`contracts/interfaces/`)**

- **New Interfaces**:
    - `IBadges.sol`: Standardize badge interactions (mint/revoke/check expiry).
    - `IPaymentPool.sol`: Define `biweeklyPayout()` and fund splitting.
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
| `Client (Customer) Token`  | ERC1155 | Product Deployment Contracts — Customer access | Pay Skypier | Preset  | N/A | Multisig | False | TBD | N/A |
| `Operator Token` | ERC1155 | Product Deployment Contracts — Node hosting | applyAsOperator() → `Validator Token` /`Employee Badge`→ ClaimOperatorNFTBadge() | No expiration | N/A | Multisig | False | EthAddr address, ValidationCount uint16, PeerID string, ActiveSince timestamp | N/A |
| `Validator Token`  | ERC1155 | Product Deployment Contracts — Node validation | applyAsValidator() → `Employee Badge`  →  ClaimValidatorNFTBadge() | No expiration | N/A | Multisig | False | EthAddr address, AddedBy address, ActiveSince timestamp | N/A |
| `Builder Token`  | ERC1155 | Internal Development Contract — Employee roles | addBuilder() by `Admin Badge` or `Project Sponsor Badge` | Preset  | N/A | Multisig | True | EthAddr address, AddedBy address, ActiveSince timestamp | N/A |
| `Investor Token`  | ERC1155 | Internal Development Contract — Investor access | ClaimInvestorNFTBadge()  | Preset  | N/A | Multisig | False | EthAddr address, AddedBy address, ActiveSince timestamp | N/A |
| `Beta Tester Badge`  | ERC1155-SFT | Pre-release access | Issue by `Employee Badge` | Inherited | 1 | Inherited | Inherited | Inherited | `Client (Customer) Token`  |
| `Employee Badge`  | ERC20 / ERC1155-SFT | Employee rewards/ Internal testing | Mintable 78 weeks after Role token has been assigned | Expires in 78 weeks after Role token expires | 6 | Inherited | Inherited | Inherited | `Builder Token`  |
| `Developer Badge`  | ERC1155-SFT | Internal developer access | Issue by `Admin Badge`  | Preset  | 1 | Inherited | Inherited | Inherited | `Builder Token`  |
| `Admin Badge`  | ERC721 |  | N/A | No expiration | N/A | Inherited | Inherited | Inherited | `Builder Token`  |
| `Annualized Badges` | ERC1155-SFT | Recognition (MVP, Mentor, etc.) | Reward from recognition  | Expires in 52 weeks | 1 per type | Inherited | Inherited | Inherited | `Builder Token`  |
| `Project Sponsor Badge` | ERC3525-SFT | Someone who proposed an accepted project/issue, as the PM/TPM/Financial Sponsor | Once DAO is established, anyone in the community can propose, vote, and financially sponsor on approved projects, once a project is approved anyone with `Employee Badge` can apply to be the TPM | Expires in 52 weeks after accepting the delivery | No Limit | Inherited | Inherited | Inherited | Applicable all Non-badge ERC1155 tokens |
| `Proof of Identity Badge` | ERC721 | Proof of humanity and identity | TBD | No expiration | 1 | Multisig | True | Inherited | Applicable all Non-badge ERC1155 tokens |
| `Skypier Token` | ERC20 | Vote and use the network | Purchase | No expiration | No Limit | True | False | N/A | N/A |

---

## **5. Payment Flow**

1. **Customers** → Pay to `Payment Pool` (ERC20).
2. **Operators** → Biweekly payouts from `Network Pool`.
3. **Builders** → Biweekly payouts from `Builder Pool` (based on `Employee Badge`).
4. **Investors** → ROI from `Builder Pool` (post-employee payouts).

---

## **6. DAO Governance**

| **DAO** | **Purpose** | **Voting Mechanism** |
| --- | --- | --- |
| **Community DAO** | Feature prioritization | Approval → Quadratic |
| **Internal DAO** | Employee equity & culture | Approval → Quadratic |




