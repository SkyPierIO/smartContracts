# Quick Reference: Contract Upgrade Status Matrix

## Color Legend
- 🟢 **Green** = Fully Compliant / Ready to Deploy
- 🟡 **Yellow** = Partially Compliant / Needs Minor Fixes  
- 🔴 **Red** = Non-Compliant / Major Refactoring Needed

---

## PRODUCT CONTRACTS (Customer-Facing)

| Contract | File | Current Status | Pattern | Issues | Priority |
|----------|------|---------|---------|--------|----------|
| **SkypierToken** | `product/tokens/SkypierToken.sol` | 🟡 | ERC20Upgradeable + UUPS | Wrong import path (line 7) | HIGH |
| **SkypierBadges** | `product/tokens/SkypierBadges.sol` | 🟢 | ERC1155Upgradeable + UUPS | None | - |
| **ClientToken** | `product/tokens/ClientToken.sol` | 🔴 | ERC1155 (non-upgradeable) | Deprecated OwnableUupsUpgradeable, non-upgradeable ERC1155 | CRITICAL |
| **OperatorToken** | `product/tokens/OperatorToken.sol` | 🔴 | ERC721 (non-upgradeable) | Completely non-upgradeable, needs rewrite | CRITICAL |
| **ValidatorToken** | `product/tokens/ValidatorToken.sol` | 🔴 | EMPTY | File is empty, must be implemented | CRITICAL |
| **SkypierVPN** | `product/SkypierVPN.sol` | 🟡 | Mixed | Uses non-upgraded imports, needs review | HIGH |
| **PaymentPool** | `product/PaymentPool.sol` | 🟡 | Mixed | Incomplete UUPS implementation | HIGH |

---

## INTERNAL CONTRACTS (Team-Facing)

| Contract | File | Current Status | Pattern | Issues | Priority |
|----------|------|---------|---------|--------|----------|
| **BuilderToken** | `internal/tokens/BuilderToken.sol` | 🟡 | ERC1155Upgradeable + AccessControl | Uses non-upgradeable AccessControl import | MEDIUM |
| **EmployeeBadge** | `internal/tokens/EmployeeBadge.sol` | 🔴 | ERC20 + Mixed | Mixed ERC20/ERC1155, non-upgradeable, missing __init__ | CRITICAL |
| **AdminBadge** | `internal/tokens/AdminBadge.sol` | 🔴 | ERC721 (non-upgradeable) | Uses non-upgradeable ERC721, deprecated Ownable pattern | CRITICAL |
| **InvestorToken** | `internal/tokens/InvestorToken.sol` | 🔴 | ERC1155 (non-upgradeable) | Uses non-upgradeable ERC1155 and AccessControl | CRITICAL |
| **AnnualizedBadges** | `internal/tokens/AnnualizedBadges.sol` | 🔴 | ERC1155 (non-upgradeable) | Uses non-upgradeable ERC1155, ReentrancyGuard, AccessControl | CRITICAL |
| **InternalDAO** | `internal/InternalDAO.sol` | 🔴 | Governor (incomplete) | Placeholder only, missing implementation | CRITICAL |
| **HumanResources** | `internal/HumanResources.sol` | 🔴 | EMPTY | File is empty, must be implemented | CRITICAL |

---

## COMMUNITY CONTRACTS (DAO & Governance)

| Contract | File | Current Status | Pattern | Issues | Priority |
|----------|------|---------|---------|--------|----------|
| **CommunityDAO** | `community/CommunityDAO.sol` | 🔴 | Governor (incomplete) | Placeholder only, missing initialization and config | CRITICAL |
| **ProjectSponsorBadge** | `community/ProjectSponsorBadge.sol` | 🔴 | ERC3525 (non-upgradeable) | Uses non-upgradeable ERC3525, no UUPS support | CRITICAL |

---

## LIBRARY & UTILITY CONTRACTS

| Contract | File | Current Status | Pattern | Issues | Priority |
|----------|------|---------|---------|--------|----------|
| **TokenBoundAccount** | `lib/TokenBoundAccount.sol` | 🔴 | ERC165 + Ownable | Uses deprecated Ownable, non-upgradeable | CRITICAL |
| **ERC6551Registry** | `lib/ERC6551Registry.sol` | 🔴 | Standalone | No upgrade capability, non-upgradeable utilities | CRITICAL |
| **Roles** | `lib/Roles.sol` | 🟢 | Library (static) | OK - purely library constants | - |
| **nodeConfig** | `lib/nodeConfig.sol` | ❓ | ? | Not reviewed | - |
| **nodeStatus** | `lib/nodeStatus.sol` | ❓ | ? | Not reviewed | - |

---

## INTERFACE CONTRACTS

| Contract | File | Status |
|----------|------|--------|
| **IAccessControl** | `interfaces/IAccessControl.sol` | 🟢 Ready |
| **IBadges** | `interfaces/IBadges.sol` | 🟢 Ready |
| **IClientToken** | `interfaces/IClientToken.sol` | 🟢 Ready |
| **IPaymentPool** | `interfaces/IPaymentPool.sol` | 🟢 Ready |
| **ISkypierVPN** | `interfaces/ISkypierVPN.sol` | 🟢 Ready |
| **ITokenBoundAccount** | `interfaces/ITokenBoundAccount.sol` | 🟢 Ready |
| **IERC6551Registry** | `interfaces/IERC6551Registry.sol` | 🟢 Ready |

---

## COMPLIANCE SCORE CARD

### Current Status
```
✅ Compliant (Upgradeable):     3/18 (17%)
⚠️  Partial Compliance:          3/18 (17%)
❌ Non-Compliant:              12/18 (67%)

Overall Upgrade-Readiness: 27%
```

### By Category
```
Product Contracts:    1/7 ready (14%)
Internal Contracts:   0/7 ready (0%)
Community Contracts:  0/2 ready (0%)
Libraries:           0/3 ready (0%)
Interfaces:          7/7 ready (100%)
```

---

## CRITICAL PATH - MUST FIX FIRST

These contracts **block deployment** if left unchanged:

```
🔴 BLOCKING ISSUES (Do First):
1. ValidatorToken.sol - EMPTY FILE
2. HumanResources.sol - EMPTY FILE  
3. ClientToken.sol - Deprecated OwnableUupsUpgradeable
4. OperatorToken.sol - Non-upgradeable ERC721
5. SkypierToken.sol - Import path error
6. CommunityDAO.sol - Incomplete Governor
7. InternalDAO.sol - Incomplete Governor
```

---

## RECOMMENDED FIX ORDER

### Week 1: Foundation (Base Contracts & Libraries)
```
1. Create BaseAccessControlledUpgradeableToken.sol
2. Create ExpiryManagement.sol  
3. Create BadgeMetadata.sol
4. Fix TokenBoundAccount.sol → Upgradeable
5. Fix ERC6551Registry.sol → Upgradeable
```

### Week 2: Product Tokens
```
6. Fix SkypierToken.sol (import path)
7. Convert OperatorToken.sol → ERC721Upgradeable
8. Implement ValidatorToken.sol  
9. Fix ClientToken.sol (remove OwnableUupsUpgradeable)
```

### Week 3: Internal Tokens
```
10. Convert AnnualizedBadges.sol → Upgradeable
11. Convert InvestorToken.sol → Upgradeable
12. Fix EmployeeBadge.sol (ERC20 confusion)
13. Update AdminBadge.sol (remove Ownable)
```

### Week 4: DAO & Core Logic
```
14. Implement CommunityDAO.sol (full Governor)
15. Implement InternalDAO.sol (full Governor)
16. Implement HumanResources.sol
17. Review SkypierVPN.sol and PaymentPool.sol
```

### Week 5-6: Upgrade ProjectSponsorBadge & Testing
```
18. Handle ProjectSponsorBadge.sol (ERC3525 special case)
19. Full integration testing
20. Security audit
```

---

## FILE STATUS CHECKLIST

### ✅ DELETE (Empty Files)
- [ ] `contracts/product/tokens/ValidatorToken.sol`
- [ ] `contracts/internal/HumanResources.sol`

### 🔄 REWRITE COMPLETELY
- [ ] `contracts/product/tokens/OperatorToken.sol`
- [ ] `contracts/product/tokens/ClientToken.sol`
- [ ] `contracts/internal/tokens/AnnualizedBadges.sol`
- [ ] `contracts/internal/tokens/InvestorToken.sol`
- [ ] `contracts/internal/tokens/EmployeeBadge.sol`
- [ ] `contracts/community/CommunityDAO.sol`
- [ ] `contracts/community/InternalDAO.sol`

### ⚙️ MINOR FIXES ONLY
- [ ] `contracts/product/tokens/SkypierToken.sol` (import path)
- [ ] `contracts/lib/TokenBoundAccount.sol` (add Upgradeable)
- [ ] `contracts/lib/ERC6551Registry.sol` (add Upgradeable)

### ✨ CREATE NEW
- [ ] `contracts/lib/BaseAccessControlledUpgradeableToken.sol`
- [ ] `contracts/lib/ExpiryManagement.sol`
- [ ] `contracts/lib/BadgeMetadata.sol`

---

## Import Path Reference

### ❌ WRONG (Non-Upgradeable)
```solidity
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
```

### ✅ CORRECT (Upgradeable)
```solidity
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
```

---

## Pragma Version Standardization

### Current (Inconsistent)
```
🟡 "^0.8.0"   - Too loose
🟡 "^0.8.20"  - Loose
🟡 "0.8.20"   - Pinned
```

### Recommended (Standard)
```
✅ "0.8.20" - Pinned version for production
```

**Action:** Update all to `pragma solidity 0.8.20;`

---

## Inheritance Order Standard

### ✅ CORRECT ORDER
```solidity
contract MyToken is
    Initializable,                    // 1. Initializer first
    ERC[X]Upgradeable,               // 2. Token standard
    AccessControlUpgradeable,        // 3. Access control
    ReentrancyGuardUpgradeable,      // 4. Reentrancy (if needed)
    UUPSUpgradeable                  // 5. Upgrade mechanism last
```

### ❌ INCORRECT (Current in Codebase)
```solidity
contract MyToken is
    ERC721,
    AccessControlUpgradeable,        // Mixing upgradeable/non-upgradeable
    ReentrancyGuard,                 // Non-upgradeable
    Ownable                          // Non-upgradeable
```

---

## Pattern Template for All New Token Contracts

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC[X]Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC[X]/ERC[X]Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyToken is
    Initializable,
    ERC[X]Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC[X]_init(...);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC[X]Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## Deployment Considerations

### Before Going Live:

1. **All contracts must:**
   - Have `initialize()` function (not constructor logic)
   - Have `_authorizeUpgrade()` function
   - Implement `_disableInitializers()` in constructor
   - Use UUPS proxy pattern

2. **Testing must cover:**
   - ✅ Initial deployment via proxy
   - ✅ Upgrade to new implementation
   - ✅ Upgrade rollback capability
   - ✅ Role-based access control
   - ✅ Reentrancy protection (if applicable)

3. **Deployment process:**
   ```
   1. Deploy implementation contract (not proxied)
   2. Deploy UUPS proxy pointing to implementation
   3. Call initialize() through proxy
   4. Verify proxy functionality
   5. Test upgrade to new implementation
   ```

---

## Post-Upgrade Verification

After upgrading each contract:

```bash
✅ Check:
- Proxy admin is set to expected address
- Implementation is correctly set
- State is preserved
- All functions accessible
- Role-based access works
- Events emitted correctly
- Gas usage acceptable

✅ Test:
- Mint/burn operations
- Access control enforcement
- State queries return correct values
- New version functionality works
```

---

## Risk Assessment

### HIGH RISK (If Not Fixed)
- Contract lock-in (cannot upgrade)
- Storage layout conflicts during upgrade
- Access control bypass vulnerabilities
- State loss during migration

### MITIGATION STRATEGY
- All contracts deployed behind UUPS proxies
- Extensive upgrade testing before mainnet
- Staged rollout (testnet → staging → mainnet)
- Emergency pause mechanism in PaymentPool
- Guardian role for critical operations

---

## Dependencies & Prerequisites

### Required OpenZeppelin Packages:
```json
{
  "@openzeppelin/contracts": "^5.4.0",
  "@openzeppelin/contracts-upgradeable": "^5.2.0",
  "@openzeppelin/hardhat-upgrades": "^3.9.0"
}
```

### Required for Tests:
```bash
npm install hardhat hardhat-upgrades
```

### Compilation Check:
```bash
npx hardhat compile
```

---

## Questions to Resolve

1. **ERC-3525 Upgrade Strategy:** How to handle non-upgradeable ERC3525 library?
   - Option A: Create wrapper contract
   - Option B: Fork and create upgradeable version
   - Option C: Migrate to different standard

2. **State Migration:** For contracts being rewritten (AdminBadge, EmployeeBadge):
   - Should existing token data be migrated?
   - Is a transition period needed?

3. **Governance Tokens:** Do SkypierToken holders have voting rights?
   - If yes, implement ERC20VotesUpgradeable
   - If no, current approach is OK

4. **PaymentPool Completeness:** Is this contract finished?
   - Appears incomplete (missing key logic)
   - Needs review before upgrade

---

## Timeline Estimate

| Phase | Tasks | Duration | Team Size |
|-------|-------|----------|-----------|
| Foundation | Create libs, fix core | 1 week | 1-2 devs |
| Product | Convert tokens | 1 week | 2 devs |
| Internal | Convert badges | 1 week | 1-2 devs |
| DAO | Implement governance | 1 week | 1 dev |
| Testing | Full test suite | 1-2 weeks | 1 QA + 1 dev |
| **Total** | | **4-6 weeks** | 2-3 core devs |

---

## Success Criteria

✅ All 18 contracts use UUPSUpgradeable pattern  
✅ Zero non-upgradeable ERC imports in production code  
✅ 100% test coverage for upgrade paths  
✅ All base contracts extracted to libraries  
✅ Consistent pragma and inheritance patterns  
✅ No empty contract files  
✅ All DAO implementations complete  
✅ Security audit passes with no critical findings  

---

## Contacts & Escalation

For architecture questions:  
→ See [SMART_CONTRACT_AUDIT_REPORT.md](SMART_CONTRACT_AUDIT_REPORT.md)

For implementation details:  
→ See [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)

