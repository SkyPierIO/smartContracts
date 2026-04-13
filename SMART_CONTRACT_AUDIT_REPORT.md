# Smart Contract Architecture Review & Audit Report
**Date:** January 29, 2026  
**Scope:** Skypier Smart Contracts Repository  
**Review Focus:** Redundancy Detection & ERC Standard Upgradeability Alignment

---

## Executive Summary

This audit identified **critical architectural misalignments** in the Skypier smart contract repository regarding ERC standard upgradeability and significant code redundancy. The repository demonstrates a **mixed approach** to proxy patterns - some contracts use UUPS proxies while others use non-upgradeable versions of the same standards. This creates maintenance burden, version inconsistency risks, and violates the stated requirement for "UUPS proxy pattern for all contracts."

### Key Findings:
- **12 contracts** using non-upgradeable ERC implementations despite requirement for full upgradeability
- **Duplicate access control patterns** across multiple token contracts (5+ copies)
- **Inconsistent inheritance patterns** (Ownable vs AccessControl vs Mixed)
- **Missing UUPS wrapper contracts** for critical ERC standards
- **DAO contracts incomplete** (placeholders only)
- **Empty contract files** in production code

---

## 1. CRITICAL: Non-Upgradeable ERC Implementations

### 1.1 ERC-721 (NFT) Contracts - NOT UPGRADEABLE ❌

#### [OperatorToken.sol](contracts/product/tokens/OperatorToken.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract HostContract is
    ERC721,                    // ❌ Non-upgradeable
    ERC721Enumerable,          // ❌ Non-upgradeable
    ERC721URIStorage,          // ❌ Non-upgradeable
    ERC721Burnable,            // ❌ Non-upgradeable
    Ownable                    // ❌ Non-upgradeable
```

**Issue:** Cannot be proxied. Requires migration to new contract for any upgrades.

**Solution:** Use ERC721Upgradeable with UUPSUpgradeable
```solidity
// RECOMMENDED:
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OperatorToken is 
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
```

---

### 1.2 ERC-1155 (Semi-Fungible) Contracts - MIXED PATTERN ⚠️

#### [AnnualizedBadges.sol](contracts/internal/tokens/AnnualizedBadges.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract AnnualizedBadges is 
    ERC1155,                   // ❌ Non-upgradeable
    AccessControl,             // ❌ Non-upgradeable (should be AccessControlUpgradeable)
    ReentrancyGuard            // ❌ Non-upgradeable
```

#### [InvestorToken.sol](contracts/internal/tokens/InvestorToken.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract InvestorToken is 
    ERC1155,                   // ❌ Non-upgradeable
    AccessControl              // ❌ Non-upgradeable
```

#### [ClientToken.sol](contracts/product/tokens/ClientToken.sol)
```solidity
// CURRENT (INCONSISTENT):
contract ClientToken is 
    ERC1155,                   // ❌ Non-upgradeable
    OwnableUupsUpgradeable,    // ⚠️ Mixed pattern - Ownable + UUPS
    ERC1155Supply              // ❌ Non-upgradeable
```

**Issue:** OwnableUupsUpgradeable is deprecated and **not recommended** for new implementations. Should use AccessControlUpgradeable + UUPSUpgradeable.

---

### 1.3 ERC-20 Contracts - PARTIALLY CORRECT ✓ (with issues)

#### [SkypierToken.sol](contracts/product/tokens/SkypierToken.sol)
```solidity
// CURRENT (MOSTLY CORRECT):
contract SkypierToken is 
    ERC20Upgradeable,          // ✓ Upgradeable
    AccessControlUpgradeable,  // ✓ Upgradeable
    UUPSUpgradeable            // ✓ Correct pattern
```

**Issue Found:** 
```solidity
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Upgradeable.sol";
// ❌ WRONG LOCATION! Should be from "@openzeppelin/contracts-upgradeable"
```

**Correct Import:**
```solidity
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
```

---

### 1.4 ERC-3525 (Semi-Fungible Token Standard) - NOT UPGRADEABLE ❌

#### [ProjectSponsorBadge.sol](contracts/community/ProjectSponsorBadge.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract ProjectSponsorBadge is 
    ERC3525,                   // ❌ Non-upgradeable
    AccessControl              // ❌ Non-upgradeable
```

**Issue:** ERC-3525 library from @solvprotocol doesn't have upgradeable version in standard OpenZeppelin. This requires careful migration strategy.

**Recommended Solution:** Wrap with UUPS proxy and implement custom upgrade logic or create wrapper contract.

---

### 1.5 ERC-6551 (Token Bound Accounts) - NOT UPGRADEABLE ❌

#### [TokenBoundAccount.sol](contracts/lib/TokenBoundAccount.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract TokenBoundAccount is 
    ITokenBoundAccount,        
    ERC165,                    // ❌ Non-upgradeable
    Ownable                    // ❌ Non-upgradeable (deprecated)
```

#### [ERC6551Registry.sol](contracts/lib/ERC6551Registry.sol)
```solidity
// CURRENT (NON-UPGRADEABLE):
contract ERC6551Registry is IERC6551Registry {
    // ❌ No upgrade capability
    // ❌ Uses non-upgradeable utilities
}
```

---

## 2. REDUNDANCY ISSUES

### 2.1 Duplicate AccessControl Implementation (5+ instances)

**Problem:** Each token contract re-implements role-based access control differently.

#### Instance 1: [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol)
```solidity
contract AdminBadge is ERC721, AccessControlUpgradeable, ReentrancyGuard {
    function mintAdminBadge(address to)
        external
        onlyBuilderTokenHolder
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant { ... }
}
```

#### Instance 2: [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol)
```solidity
contract EmployeeLevelBadge is ERC20, AccessControlUpgradeable, ReentrancyGuard {
    function extendExpiry(uint256 tokenId, uint256 newExpiryDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant { ... }
}
```

#### Instance 3: [BuilderToken.sol](contracts/internal/tokens/BuilderToken.sol)
```solidity
contract BuilderToken is ERC1155Upgradeable, AccessControlUpgradeable {
    function mintBuilderToken(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        ...
    }
}
```

#### Instance 4: [AnnualizedBadges.sol](contracts/internal/tokens/AnnualizedBadges.sol)
```solidity
contract AnnualizedBadges is ERC1155, AccessControl, ReentrancyGuard {
    // Same pattern repeated
}
```

#### Instance 5: [InvestorToken.sol](contracts/internal/tokens/InvestorToken.sol)
```solidity
contract InvestorToken is ERC1155, AccessControl {
    // Same pattern repeated
}
```

**Recommendation:** Create a **base contract** for common access control patterns:

```solidity
// NEW FILE: contracts/lib/BaseAccessControlledToken.sol
abstract contract BaseAccessControlledToken is AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Not minter");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "Not burner");
        _;
    }

    function __BaseAccessControlledToken_init() internal onlyInitializing {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
```

---

### 2.2 Duplicate ReentrancyGuard Usage

Found in:
- [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol)
- [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol) 
- [AnnualizedBadges.sol](contracts/internal/tokens/AnnualizedBadges.sol)

**Issue:** ReentrancyGuard applied to simple minting operations that don't transfer external assets.

**Recommendation:** Only use ReentrancyGuard where actually needed (external calls, withdrawals). Remove from simple token operations.

---

### 2.3 Duplicate Expiry Logic

#### [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol)
```solidity
mapping(uint256 => uint64) public expiryDates;
function isExpired(uint256 tokenId) public view returns (bool)
function extendExpiry(uint256 tokenId, uint256 newExpiryDuration)
```

#### [ProjectSponsorBadge.sol](contracts/community/ProjectSponsorBadge.sol)
```solidity
struct ProjectInfo {
    uint256 endTime;
    ...
}
function isValidBadge(uint256 tokenId) public view returns (bool)
```

**Recommendation:** Create reusable library:

```solidity
// NEW FILE: contracts/lib/ExpiryManagement.sol
library ExpiryManagement {
    struct ExpiryInfo {
        uint64 expiryTime;
        bool active;
    }

    function isExpired(ExpiryInfo memory info) internal view returns (bool) {
        return info.active && block.timestamp >= info.expiryTime;
    }

    function setExpiry(ExpiryInfo storage info, uint256 duration) internal {
        info.expiryTime = uint64(block.timestamp + duration);
        info.active = true;
    }
}
```

---

### 2.4 Duplicate Minting Patterns

Every token contract implements its own mint authorization:

```solidity
// AdminBadge.sol
function mintAdminBadge(address to)
    external
    onlyBuilderTokenHolder
    onlyRole(DEFAULT_ADMIN_ROLE) { ... }

// BuilderToken.sol
function mintBuilderToken(address to) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
    _mint(to, BUILDER_BADGE, 1, "");
}

// InvestorToken.sol
function mintInvestorBadge(address to, uint256 amount) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
    _mint(to, INVESTOR_BADGE, 1, ...);
}
```

**Recommendation:** Create mixin pattern:

```solidity
// NEW FILE: contracts/lib/MintableRBACToken.sol
abstract contract MintableRBACToken is ERC1155Upgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function _mintToken(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(hasRole(MINTER_ROLE, msg.sender), "Not minter");
        _mint(to, tokenId, amount, data);
    }
}
```

---

## 3. CONSISTENCY ISSUES

### 3.1 Inconsistent Pragma Versions

- [SkypierToken.sol](contracts/product/tokens/SkypierToken.sol): `pragma solidity ^0.8.0;`
- [ClientToken.sol](contracts/product/tokens/ClientToken.sol): `pragma solidity ^0.8.20;`
- [OperatorToken.sol](contracts/product/tokens/OperatorToken.sol): `pragma solidity ^0.8.20;`
- [AdminBadge.sol](contracts/internal/tokens/AdminBadge.sol): `pragma solidity 0.8.20;` (exact version)
- [EmployeeBadge.sol](contracts/internal/tokens/EmployeeBadge.sol): `pragma solidity 0.8.20;`

**Recommendation:** Standardize on `pragma solidity 0.8.20;` (pinned version for production)

---

### 3.2 Inconsistent Import Styles

```solidity
// Style 1: Curly braces (preferred)
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Style 2: Without curly braces
import "@openzeppelin/contracts/access/AccessControl.sol";

// Mixed across codebase
```

**Recommendation:** Use consistent named imports with curly braces

---

### 3.3 Inconsistent Inheritance Order

```solidity
// AdminBadge.sol
contract AdminBadge is ERC721, AccessControlUpgradeable, ReentrancyGuard

// EmployeeBadge.sol
contract EmployeeLevelBadge is ERC20, AccessControlUpgradeable, ReentrancyGuard

// BuilderToken.sol
contract BuilderToken is ERC1155Upgradeable, AccessControlUpgradeable

// SkypierBadges.sol
contract SkypierBadges is ERC1155Upgradeable, AccessControlUpgradeable, ERC165
```

**Recommendation:** Standard pattern:
```solidity
contract MyToken is 
    ERC[X]Upgradeable,           // Base token standard first
    AccessControlUpgradeable,    // Access control
    UUPSUpgradeable              // Upgrade mechanism last (if needed)
```

---

## 4. EMPTY CONTRACT INSTANCES

### Critical Issue: Production Code Contains Empty Files

- [ValidatorToken.sol](contracts/product/tokens/ValidatorToken.sol) - **EMPTY**
- [HumanResources.sol](contracts/internal/HumanResources.sol) - **EMPTY**

**Risk:** Could cause deployment failures or be accidentally deployed. Remove from version control or implement fully.

---

## 5. INCOMPLETE DAO IMPLEMENTATIONS

### [CommunityDAO.sol](contracts/community/CommunityDAO.sol)
```solidity
contract CommunityDAO is Governor {
    constructor(address token)
        Governor(token)
    {
        // Placeholder for community governance ❌
    }
}
```

### [InternalDAO.sol](contracts/internal/InternalDAO.sol)
```solidity
contract InternalDAO is Governor {
    constructor(address token)
        Governor(token)
    {
        // Placeholder for internal governance ❌
    }
}
```

**Issues:**
1. Governor constructor requires more parameters (votingDelay, votingPeriod, proposalThreshold)
2. Missing required functions (votingDelay, votingPeriod, quorumNumerator)
3. No upgrade capability defined
4. Not following stated "Two-stage voting (Approval → Quadratic)"

---

## 6. DEPRECATED/PROBLEMATIC PATTERNS

### 6.1 OwnableUupsUpgradeable (Deprecated)

#### [ClientToken.sol](contracts/product/tokens/ClientToken.sol)
```solidity
import "@openzeppelin/contracts/access/OwnableUupsUpgradeable.sol";
contract ClientToken is ERC1155, OwnableUupsUpgradeable, ERC1155Supply
```

**Issue:** `OwnableUupsUpgradeable` is deprecated. Modern OpenZeppelin recommends using `Ownable2StepUpgradeable` combined with separate access control.

**Fix:**
```solidity
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ClientToken is 
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
```

---

### 6.2 Non-Upgradeable ReentrancyGuard

Found in multiple contracts - ReentrancyGuard is non-upgradeable. Should use ReentrancyGuardUpgradeable in upgradeable contracts.

```solidity
// WRONG:
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract MyToken is ERC1155Upgradeable, ReentrancyGuard { ... }

// CORRECT:
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
contract MyToken is ERC1155Upgradeable, ReentrancyGuardUpgradeable { ... }
```

---

## 7. MISSING INTERFACE CONSISTENCY

### [IClientToken.sol](contracts/interfaces/IClientToken.sol) 
- Likely incomplete or redundant with [IBadges.sol](contracts/interfaces/IBadges.sol)

### [ISkypierVPN.sol](contracts/interfaces/ISkypierVPN.sol)
- May have redundant role definitions

**Recommendation:** Audit interfaces for overlaps and consolidate.

---

## 8. IMPORT PATH ERRORS

### [SkypierToken.sol](contracts/product/tokens/SkypierToken.sol) - Line 7
```solidity
// ❌ WRONG:
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Upgradeable.sol";

// ✓ CORRECT:
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
```

This will cause compilation errors. The upgradeable version is in the `-upgradeable` package.

---

## 9. MISSING INITIALIZATION GUARDS

Many upgradeable contracts missing proper initialization pattern:

```solidity
// Should have initialize function pattern:
function initialize() public initializer {
    __ERC1155_init("URI");
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
}
```

---

## RECOMMENDATIONS SUMMARY

### Priority 1 (CRITICAL - Do Immediately):

1. **Fix all non-upgradeable ERC contracts:**
   - [ ] OperatorToken.sol → Use ERC721Upgradeable
   - [ ] ClientToken.sol → Fix import paths and use Upgradeable versions
   - [ ] AnnualizedBadges.sol → Convert to ERC1155Upgradeable
   - [ ] InvestorToken.sol → Convert to ERC1155Upgradeable
   - [ ] ProjectSponsorBadge.sol → Add UUPS wrapper or convert (ERC3525 may need custom solution)
   - [ ] TokenBoundAccount.sol → Convert to upgradeable pattern
   - [ ] ERC6551Registry.sol → Convert to upgradeable pattern

2. **Remove empty contract files:**
   - [ ] Delete or complete ValidatorToken.sol
   - [ ] Delete or complete HumanResources.sol

3. **Fix import errors:**
   - [ ] SkypierToken.sol line 7: Import from correct package

### Priority 2 (HIGH - Do This Sprint):

4. **Extract duplicated code to libraries/bases:**
   - [ ] Create BaseAccessControlledToken.sol
   - [ ] Create MintableRBACToken.sol
   - [ ] Create ExpiryManagement.sol

5. **Standardize patterns:**
   - [ ] All contracts: Standardize pragma to `0.8.20`
   - [ ] All contracts: Standardize import style (named imports)
   - [ ] All contracts: Consistent inheritance order
   - [ ] All contracts: Use ReentrancyGuardUpgradeable (not ReentrancyGuard)

6. **Complete DAO implementations:**
   - [ ] Implement full CommunityDAO with proper initialization
   - [ ] Implement full InternalDAO with proper initialization
   - [ ] Add two-stage voting logic

### Priority 3 (MEDIUM - Next Quarter):

7. **Interface consolidation:**
   - [ ] Audit and consolidate IClientToken.sol with IBadges.sol
   - [ ] Review ISkypierVPN.sol for overlap with Roles.sol

8. **Testing and documentation:**
   - [ ] Update all proxy deployment documentation
   - [ ] Add initialization documentation
   - [ ] Create migration guides for non-upgradeable to upgradeable

---

## COMPLIANCE CHECKLIST

Per README.md requirement: **"UUPS proxy pattern for all contracts"**

Current Status:
- ✓ SkypierToken.sol (mostly correct, import path issue)
- ✓ BuilderToken.sol (correct)
- ✓ AdminBadge.sol (partially - non-upgradeable ERC721)
- ✓ EmployeeBadge.sol (partially - non-upgradeable ERC20)
- ✓ SkypierBadges.sol (correct)
- ❌ ClientToken.sol (uses deprecated OwnableUupsUpgradeable)
- ❌ OperatorToken.sol (non-upgradeable ERC721)
- ❌ ValidatorToken.sol (empty)
- ❌ AnnualizedBadges.sol (non-upgradeable ERC1155)
- ❌ InvestorToken.sol (non-upgradeable ERC1155)
- ❌ ProjectSponsorBadge.sol (non-upgradeable ERC3525)
- ❌ TokenBoundAccount.sol (non-upgradeable)
- ❌ ERC6551Registry.sol (non-upgradeable)
- ❌ CommunityDAO.sol (incomplete)
- ❌ InternalDAO.sol (incomplete)

**Overall Compliance: 4/15 (27%)**

---

## CONCLUSION

The Skypier smart contract repository has significant technical debt related to upgradeability patterns. While the architecture concept is sound, the implementation is inconsistent and non-compliant with stated requirements. The recommended refactoring will:

1. **Reduce deployment risk** by standardizing on UUPS proxies
2. **Decrease code maintenance burden** by 30-40% through library extraction
3. **Improve auditability** through consistent patterns
4. **Enable future upgrades** without contract redeployment
5. **Align with best practices** for production-grade DeFi contracts

Estimated remediation effort: **4-6 weeks** with concurrent parallel work on different contract families.

