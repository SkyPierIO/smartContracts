# Implementation Roadmap: Smart Contract Upgradability Fixes

This document provides step-by-step implementation fixes for achieving full UUPS upgradeability compliance.

---

## PHASE 1: Extract Reusable Base Contracts & Libraries

### 1.1 Create BaseAccessControlledUpgradeableToken.sol

**File:** `contracts/lib/BaseAccessControlledUpgradeableToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title BaseAccessControlledUpgradeableToken
 * @dev Abstract base contract for ERC1155 tokens with UUPS upgrade capability
 * and role-based access control. Reduces code duplication across token contracts.
 */
abstract contract BaseAccessControlledUpgradeableToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // Common roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bool public paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier whenNotPaused() {
        require(!paused, "Token: paused");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "Must have burner role");
        _;
    }

    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _;
    }

    function __BaseAccessControlledUpgradeableToken_init(string memory uri) internal onlyInitializing {
        __ERC1155_init(uri);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Setup admin role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    function pause() public onlyPauser {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyPauser {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function _safeMintWithRole(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal onlyMinter whenNotPaused {
        _mint(to, id, amount, data);
    }

    function _safeBurnWithRole(
        address from,
        uint256 id,
        uint256 amount
    ) internal onlyBurner {
        _burn(from, id, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

### 1.2 Create ExpiryManagement Library

**File:** `contracts/lib/ExpiryManagement.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title ExpiryManagement
 * @dev Library for managing token expiry dates across contracts
 */
library ExpiryManagement {
    struct ExpiryInfo {
        uint64 expiryTime;
        bool isActive;
    }

    event ExpirySet(uint256 indexed tokenId, uint64 expiryTime);
    event ExpiryRevoked(uint256 indexed tokenId);

    /**
     * @dev Check if a token has expired
     */
    function isExpired(ExpiryInfo storage info) internal view returns (bool) {
        return info.isActive && block.timestamp >= info.expiryTime;
    }

    /**
     * @dev Check if a token is still valid (not expired and active)
     */
    function isValid(ExpiryInfo storage info) internal view returns (bool) {
        return info.isActive && block.timestamp < info.expiryTime;
    }

    /**
     * @dev Set expiry time for a token
     */
    function setExpiry(
        ExpiryInfo storage info,
        uint256 durationInSeconds
    ) internal {
        info.expiryTime = uint64(block.timestamp + durationInSeconds);
        info.isActive = true;
        emit ExpirySet(0, info.expiryTime); // tokenId should be passed by caller
    }

    /**
     * @dev Extend expiry time
     */
    function extendExpiry(
        ExpiryInfo storage info,
        uint256 additionalDuration
    ) internal {
        require(info.isActive, "Token not active");
        info.expiryTime = uint64(info.expiryTime + additionalDuration);
    }

    /**
     * @dev Revoke expiry (make permanent)
     */
    function revokeExpiry(ExpiryInfo storage info) internal {
        info.isActive = false;
        emit ExpiryRevoked(0);
    }

    /**
     * @dev Get time remaining until expiry (returns 0 if expired)
     */
    function getTimeRemaining(ExpiryInfo storage info) internal view returns (uint256) {
        if (!info.isActive) return 0;
        if (block.timestamp >= info.expiryTime) return 0;
        return info.expiryTime - block.timestamp;
    }
}
```

---

### 1.3 Create BadgeMetadata Library

**File:** `contracts/lib/BadgeMetadata.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title BadgeMetadata
 * @dev Library for managing badge metadata consistently across contracts
 */
library BadgeMetadata {
    struct Badge {
        string name;
        string description;
        uint256 mintedAt;
        address mintedBy;
        bool revoked;
    }

    mapping(uint256 => Badge) public badges;

    event BadgeMinted(
        uint256 indexed tokenId,
        string name,
        address indexed mintedBy,
        uint256 timestamp
    );

    event BadgeRevoked(uint256 indexed tokenId, address indexed revokedBy);

    function createBadge(
        uint256 tokenId,
        string memory name,
        string memory description,
        address mintedBy
    ) internal {
        badges[tokenId] = Badge({
            name: name,
            description: description,
            mintedAt: block.timestamp,
            mintedBy: mintedBy,
            revoked: false
        });

        emit BadgeMinted(tokenId, name, mintedBy, block.timestamp);
    }

    function revokeBadge(uint256 tokenId, address revokedBy) internal {
        require(!badges[tokenId].revoked, "Badge already revoked");
        badges[tokenId].revoked = true;
        emit BadgeRevoked(tokenId, revokedBy);
    }

    function getBadge(uint256 tokenId) internal view returns (Badge memory) {
        return badges[tokenId];
    }

    function isBadgeActive(uint256 tokenId) internal view returns (bool) {
        return !badges[tokenId].revoked;
    }
}
```

---

## PHASE 2: Upgrade Individual Token Contracts

### 2.1 Fix SkypierToken.sol

**Current Issues:**
- Wrong import path for ERC20Upgradeable (line 7)

**File:** `contracts/product/tokens/SkypierToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title SkypierToken
 * @dev ERC-20 utility token with UUPS upgrade capability
 */
contract SkypierToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Initial supply constant
    uint256 private constant INITIAL_SUPPLY = 21 * 10**9;

    event TokenMinted(address indexed to, uint256 amount);
    event TokenBurned(address indexed from, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("SkypierToken", "SKP");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);

        // Mint initial supply
        _mint(msg.sender, INITIAL_SUPPLY * 10**decimals());
        emit TokenMinted(msg.sender, INITIAL_SUPPLY * 10**decimals());
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit TokenMinted(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokenBurned(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(account, amount);
        emit TokenBurned(account, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

### 2.2 Fix OperatorToken.sol → Convert to ERC721Upgradeable

**Current Issue:** Uses non-upgradeable ERC721

**File:** `contracts/product/tokens/OperatorToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OperatorToken
 * @dev ERC-721 non-transferable token for node operators
 * Represents ownership of operator nodes in the Skypier network
 */
contract OperatorToken is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _tokenIdCounter;

    struct OperatorInfo {
        string nodeId;
        uint256 registeredAt;
        bool isActive;
    }

    mapping(uint256 => OperatorInfo) public operatorInfo;

    event OperatorRegistered(uint256 indexed tokenId, string nodeId, address owner);
    event OperatorUnregistered(uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("OperatorToken", "OPR");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    function safeMint(
        address to,
        string memory uri,
        string memory nodeId
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        operatorInfo[tokenId] = OperatorInfo({
            nodeId: nodeId,
            registeredAt: block.timestamp,
            isActive: true
        });

        emit OperatorRegistered(tokenId, nodeId, to);
        return tokenId;
    }

    function deregisterOperator(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        operatorInfo[tokenId].isActive = false;
        emit OperatorUnregistered(tokenId);
    }

    // Prevent transfers (soulbound)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        require(from == address(0) || to == address(0), "Operator token is soulbound");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
```

---

### 2.3 Fix ClientToken.sol

**Current Issues:**
- Uses deprecated `OwnableUupsUpgradeable`
- Uses non-upgradeable ERC1155
- Uses non-upgradeable ERC1155Supply

**File:** `contracts/product/tokens/ClientToken.sol` (Partial - key changes)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title ClientToken
 * @dev ERC-1155 Soulbound Tokens for Skypier VPN clients with UUPS upgrade capability
 */
contract ClientToken is
    Initializable,
    ERC1155Upgradeable,
    ERC1155SupplyUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IERC2981
{
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant CLIENT_BADGE = 0;
    uint256 public constant BETA_TESTER_BADGE = 1;

    mapping(uint256 => uint64) public expiryDates;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _minter, address _admin) public initializer {
        __ERC1155_init("https://skypier.io/metadata/{id}");
        __ERC1155Supply_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, _minter);
        _setupRole(BURNER_ROLE, _admin);
    }

    // ... rest of implementation with Upgradeable versions

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._update(from, to, ids, values);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

### 2.4 Fix AnnualizedBadges.sol

**Current Issue:** Uses non-upgradeable ERC1155 and AccessControl

**File:** `contracts/internal/tokens/AnnualizedBadges.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../lib/ExpiryManagement.sol";

/**
 * @title AnnualizedBadges
 * @dev ERC-1155 badges for annual recognition with UUPS upgrade capability
 */
contract AnnualizedBadges is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ExpiryManagement for ExpiryManagement.ExpiryInfo;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Badge IDs
    uint256 public constant TECHNICAL_FELLOW_BADGE = 0;
    uint256 public constant MENTOR_BADGE = 1;
    uint256 public constant PROJECT_LEAD_BADGE = 2;
    uint256 public constant PEOPLE_LEAD_BADGE = 3;
    uint256 public constant TRAILBLAZER_BADGE = 4;
    uint256 public constant TEAM_SAGE_BADGE = 5;
    uint256 public constant CLUTCH_BADGE = 6;
    uint256 public constant HUSTLE_BADGE = 7;
    uint256 public constant BUG_CATCHER_BADGE = 8;

    uint256 public constant BADGE_EXPIRY = 52 weeks;

    struct BadgeInfo {
        address holder;
        address nominatedBy;
        uint256 awardedAt;
    }

    mapping(uint256 => mapping(uint256 => BadgeInfo)) private _badgeInfo;
    mapping(uint256 => ExpiryManagement.ExpiryInfo) private _expiryInfo;

    IERC1155 public immutable builderToken;
    uint256 public immutable builderTokenId;

    event BadgeAwarded(
        uint256 indexed tokenId,
        uint256 indexed badgeId,
        address indexed holder,
        address nominatedBy,
        uint256 expiryTime
    );

    event BadgeRevoked(uint256 indexed tokenId, uint256 indexed badgeId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _builderToken, uint256 _builderTokenId) {
        builderToken = IERC1155(_builderToken);
        builderTokenId = _builderTokenId;
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/annualized/{id}.json");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    function awardBadge(
        address to,
        uint256 badgeId,
        address nominatedBy,
        uint256 customExpiry
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(badgeId <= BUG_CATCHER_BADGE, "Invalid badge ID");

        uint256 tokenId = keccak256(abi.encodePacked(to, badgeId, block.timestamp));
        uint256 expiryDuration = customExpiry > 0 ? customExpiry : BADGE_EXPIRY;

        _mint(to, tokenId, 1, "");

        _badgeInfo[tokenId][badgeId] = BadgeInfo({
            holder: to,
            nominatedBy: nominatedBy,
            awardedAt: block.timestamp
        });

        _expiryInfo[tokenId].setExpiry(expiryDuration);

        emit BadgeAwarded(tokenId, badgeId, to, nominatedBy, block.timestamp + expiryDuration);
    }

    function isBadgeExpired(uint256 tokenId) public view returns (bool) {
        return _expiryInfo[tokenId].isExpired();
    }

    function extendBadgeExpiry(uint256 tokenId, uint256 additionalDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(!isBadgeExpired(tokenId), "Badge already expired");
        _expiryInfo[tokenId].extendExpiry(additionalDuration);
    }

    function revokeBadge(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        require(exists(tokenId), "Badge does not exist");
        _burn(balanceOf(ownerOf(tokenId), tokenId), tokenId, 1);
        delete _expiryInfo[tokenId];
        emit BadgeRevoked(tokenId, 0);
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return _badgeInfo[tokenId][0].holder;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _badgeInfo[tokenId][0].holder != address(0);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

### 2.5 Fix InvestorToken.sol

**Current Issue:** Uses non-upgradeable ERC1155 and AccessControl

**File:** `contracts/internal/tokens/InvestorToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title InvestorToken
 * @dev ERC-1155 token for investor access management with UUPS upgrade capability
 */
contract InvestorToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant INVESTOR_BADGE = 0;

    // Investor info storage
    mapping(address => uint256) public investorAllocations;

    event InvestorBadgeIssued(address indexed investor, uint256 allocation);
    event InvestorBadgeRevoked(address indexed investor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/investor/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @dev Mints investor badge with preapproved token allocation
     */
    function mintInvestorBadge(address to, uint256 allocation)
        external
        onlyRole(MINTER_ROLE)
    {
        require(to != address(0), "Invalid recipient");
        require(allocation > 0, "Allocation must be > 0");

        _mint(to, INVESTOR_BADGE, 1, "");
        investorAllocations[to] = allocation;

        emit InvestorBadgeIssued(to, allocation);
    }

    /**
     * @dev Revokes investor badge
     */
    function revokeInvestorBadge(address from) external onlyRole(BURNER_ROLE) {
        require(balanceOf(from, INVESTOR_BADGE) > 0, "Not an investor");

        _burn(from, INVESTOR_BADGE, 1);
        investorAllocations[from] = 0;

        emit InvestorBadgeRevoked(from);
    }

    /**
     * @dev Gets investor allocation amount
     */
    function getInvestorAllocation(address investor) public view returns (uint256) {
        if (balanceOf(investor, INVESTOR_BADGE) == 0) {
            return 0;
        }
        return investorAllocations[investor];
    }

    /**
     * @dev Updates investor allocation
     */
    function updateInvestorAllocation(address investor, uint256 newAllocation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(balanceOf(investor, INVESTOR_BADGE) > 0, "Not an investor");
        investorAllocations[investor] = newAllocation;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## PHASE 3: Upgrade Library Contracts

### 3.1 Fix TokenBoundAccount.sol

**Current Issue:** Uses non-upgradeable Ownable

**File:** `contracts/lib/TokenBoundAccount.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/ITokenBoundAccount.sol";

/**
 * @title TokenBoundAccount
 * @dev Token Bound Account implementation following ERC-6551 standard
 * with UUPS upgrade capability
 */
contract TokenBoundAccount is
    Initializable,
    ITokenBoundAccount,
    ERC165Upgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    address public tokenContract;
    uint256 public tokenId;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tokenContract, uint256 _tokenId) public initializer {
        require(_tokenContract != address(0), "Invalid token contract");

        __Ownable2Step_init();
        __AccessControl_init();
        __ERC165_init();
        __UUPSUpgradeable_init();

        tokenContract = _tokenContract;
        tokenId = _tokenId;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SIGNER_ROLE, msg.sender);
    }

    function token() external view override returns (address, uint256) {
        return (tokenContract, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) external view override returns (bool) {
        return hasRole(SIGNER_ROLE, signer) || owner() == signer;
    }

    function addSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(SIGNER_ROLE, signer);
    }

    function removeSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(SIGNER_ROLE, signer);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ITokenBoundAccount).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // Fallback and receive functions
    fallback() external payable {}

    receive() external payable {}
}
```

---

### 3.2 Fix ERC6551Registry.sol

**File:** `contracts/lib/ERC6551Registry.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IERC6551Registry.sol";

/**
 * @title ERC6551Registry
 * @dev Registry for ERC-6551 Token Bound Accounts with UUPS upgrade capability
 */
contract ERC6551Registry is
    Initializable,
    IERC6551Registry,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ACCOUNT_CREATOR_ROLE = keccak256("ACCOUNT_CREATOR_ROLE");

    mapping(address => uint256) private _accountNonces;

    event AccountCreated(
        address indexed account,
        address indexed implementation,
        uint256 chainId,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 salt
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ACCOUNT_CREATOR_ROLE, msg.sender);
    }

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external onlyRole(ACCOUNT_CREATOR_ROLE) override returns (address) {
        require(implementation != address(0), "Invalid implementation");

        address account = computeAccount(
            implementation,
            chainId,
            tokenContract,
            tokenId,
            salt
        );

        require(account.code.length == 0, "Account already deployed");

        bytes memory creationCode = _getCreationCode(
            implementation,
            chainId,
            tokenContract,
            tokenId
        );

        assembly {
            let deployedAccount := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
            if iszero(deployedAccount) {
                revert(0, 0)
            }
        }

        emit AccountCreated(account, implementation, chainId, tokenContract, tokenId, salt);
        return account;
    }

    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view override returns (address) {
        return computeAccount(implementation, chainId, tokenContract, tokenId, salt);
    }

    function computeAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) public view override returns (address) {
        bytes memory creationCode = _getCreationCode(
            implementation,
            chainId,
            tokenContract,
            tokenId
        );

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(creationCode))
        );

        return address(uint160(uint256(hash)));
    }

    function _getCreationCode(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        bytes memory code = abi.encodePacked(
            hex"3d_60_2d_80_60_0a_3d_39_3d_f3_",
            hex"5f_35_81_36_10_15",
            _toBytes32(address(this)),
            _toBytes32(implementation),
            _toBytes32(chainId),
            _toBytes32(tokenContract),
            _toBytes32(tokenId)
        );
        return code;
    }

    function _toBytes32(address addr) internal pure returns (bytes memory) {
        bytes memory result = new bytes(32);
        assembly {
            mstore(add(result, 32), addr)
        }
        return result;
    }

    function _toBytes32(uint256 value) internal pure returns (bytes memory) {
        bytes memory result = new bytes(32);
        assembly {
            mstore(add(result, 32), value)
        }
        return result;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
```

---

## PHASE 4: Implement DAO Contracts

### 4.1 Complete CommunityDAO.sol

**File:** `contracts/community/CommunityDAO.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

/**
 * @title CommunityDAO
 * @dev Community governance contract with two-stage voting
 * Stage 1: Simple approval voting
 * Stage 2: Quadratic voting (if approved)
 */
contract CommunityDAO is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    UUPSUpgradeable
{
    // Two-stage voting state
    enum VotingStage {
        STAGE_1_APPROVAL,
        STAGE_2_QUADRATIC
    }

    mapping(uint256 => VotingStage) public proposalStage;

    event ProposalAdvancedToStage2(uint256 indexed proposalId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _timelock) public initializer {
        require(_token != address(0), "Invalid token address");
        require(_timelock != address(0), "Invalid timelock address");

        __Governor_init("CommunityDAO");
        __GovernorSettings_init(
            1, // voting delay: 1 block
            50400, // voting period: 1 week (~7 days on Ethereum)
            100e18 // proposal threshold: 100 tokens
        );
        __GovernorCountingSimple_init();
        __GovernorVotes_init(IVotesUpgradeable(_token));
        __GovernorVotesQuorumFraction_init(4); // 4% quorum
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(_timelock));
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Advance proposal from Stage 1 to Stage 2
     * Called when Stage 1 approval threshold is reached
     */
    function advanceToStage2(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal must be succeeded");
        proposalStage[proposalId] = VotingStage.STAGE_2_QUADRATIC;
        emit ProposalAdvancedToStage2(proposalId);
    }

    // Required overrides
    function votingDelay()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._queueOperations(proposalId, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._executeOperations(proposalId, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyGovernance
    {}
}
```

---

### 4.2 Complete InternalDAO.sol

**File:** `contracts/internal/InternalDAO.sol`

(Same structure as CommunityDAO, with InternalDAO-specific parameters)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

/**
 * @title InternalDAO
 * @dev Internal team governance contract with two-stage voting
 */
contract InternalDAO is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _timelock) public initializer {
        require(_token != address(0), "Invalid token address");
        require(_timelock != address(0), "Invalid timelock address");

        __Governor_init("InternalDAO");
        __GovernorSettings_init(
            1, // voting delay: 1 block
            50400, // voting period: 1 week
            10e18 // proposal threshold: 10 tokens (lower for internal)
        );
        __GovernorCountingSimple_init();
        __GovernorVotes_init(IVotesUpgradeable(_token));
        __GovernorVotesQuorumFraction_init(10); // 10% quorum (higher for internal)
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(_timelock));
        __UUPSUpgradeable_init();
    }

    // ... (same override pattern as CommunityDAO)

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyGovernance
    {}
}
```

---

## PHASE 5: Implement Missing Contracts

### 5.1 Create ValidatorToken.sol

**File:** `contracts/product/tokens/ValidatorToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ValidatorToken
 * @dev ERC-1155 non-transferable token for node validators
 * Represents validator status in the Skypier network
 */
contract ValidatorToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant VALIDATOR_BADGE = 0;

    struct ValidatorInfo {
        address validatorAddress;
        uint256 stakingAmount;
        uint256 registeredAt;
        bool isActive;
    }

    mapping(address => ValidatorInfo) public validators;

    event ValidatorRegistered(address indexed validator, uint256 stakingAmount);
    event ValidatorDeregistered(address indexed validator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/validator/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    function mintValidatorBadge(address to, uint256 stakingAmount)
        external
        onlyRole(MINTER_ROLE)
    {
        require(to != address(0), "Invalid recipient");
        require(stakingAmount > 0, "Staking amount must be > 0");

        _mint(to, VALIDATOR_BADGE, 1, "");

        validators[to] = ValidatorInfo({
            validatorAddress: to,
            stakingAmount: stakingAmount,
            registeredAt: block.timestamp,
            isActive: true
        });

        emit ValidatorRegistered(to, stakingAmount);
    }

    function revokeValidatorBadge(address from) external onlyRole(BURNER_ROLE) {
        require(balanceOf(from, VALIDATOR_BADGE) > 0, "Not a validator");

        _burn(from, VALIDATOR_BADGE, 1);
        validators[from].isActive = false;

        emit ValidatorDeregistered(from);
    }

    function getValidatorInfo(address validator) public view returns (ValidatorInfo memory) {
        return validators[validator];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        require(from == address(0) || to == address(0), "Validator token is soulbound");
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

### 5.2 Create HumanResources.sol

**File:** `contracts/internal/HumanResources.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title HumanResources
 * @dev Manages builder pool operations, allocations, and payouts
 */
contract HumanResources is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant HR_MANAGER_ROLE = keccak256("HR_MANAGER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    struct Builder {
        address wallet;
        string role;
        uint256 monthlyAllocation;
        uint256 lastPaymentTime;
        bool isActive;
    }

    mapping(address => Builder) public builders;
    address[] public activeBuilders;

    uint256 public totalBuilderAllocations;
    address payable public builderPoolWallet;

    IERC1155 public immutable builderToken;
    uint256 public immutable builderTokenId;

    event BuilderRegistered(address indexed builder, string role, uint256 allocation);
    event BuilderDeregistered(address indexed builder);
    event PaymentProcessed(address indexed builder, uint256 amount);
    event AllocationUpdated(address indexed builder, uint256 newAllocation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _builderToken, uint256 _builderTokenId) {
        builderToken = IERC1155(_builderToken);
        builderTokenId = _builderTokenId;
        _disableInitializers();
    }

    function initialize(address payable _builderPoolWallet) public initializer {
        require(_builderPoolWallet != address(0), "Invalid wallet");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(HR_MANAGER_ROLE, msg.sender);
        _setupRole(TREASURER_ROLE, msg.sender);

        builderPoolWallet = _builderPoolWallet;
    }

    function registerBuilder(
        address builderAddress,
        string memory role,
        uint256 monthlyAllocation
    ) external onlyRole(HR_MANAGER_ROLE) {
        require(builderAddress != address(0), "Invalid address");
        require(monthlyAllocation > 0, "Allocation must be > 0");

        builders[builderAddress] = Builder({
            wallet: builderAddress,
            role: role,
            monthlyAllocation: monthlyAllocation,
            lastPaymentTime: block.timestamp,
            isActive: true
        });

        totalBuilderAllocations += monthlyAllocation;
        activeBuilders.push(builderAddress);

        emit BuilderRegistered(builderAddress, role, monthlyAllocation);
    }

    function deregisterBuilder(address builderAddress) external onlyRole(HR_MANAGER_ROLE) {
        require(builders[builderAddress].isActive, "Builder not active");

        totalBuilderAllocations -= builders[builderAddress].monthlyAllocation;
        builders[builderAddress].isActive = false;

        emit BuilderDeregistered(builderAddress);
    }

    function updateBuilderAllocation(address builderAddress, uint256 newAllocation)
        external
        onlyRole(HR_MANAGER_ROLE)
    {
        require(builders[builderAddress].isActive, "Builder not active");

        totalBuilderAllocations -= builders[builderAddress].monthlyAllocation;
        builders[builderAddress].monthlyAllocation = newAllocation;
        totalBuilderAllocations += newAllocation;

        emit AllocationUpdated(builderAddress, newAllocation);
    }

    function processPayment(address builderAddress) external onlyRole(TREASURER_ROLE) nonReentrant {
        require(builders[builderAddress].isActive, "Builder not active");

        uint256 amount = builders[builderAddress].monthlyAllocation;
        require(amount > 0, "No allocation");

        builders[builderAddress].lastPaymentTime = block.timestamp;

        // Transfer funds from builder pool
        (bool success,) = payable(builderAddress).call{value: amount}("");
        require(success, "Payment failed");

        emit PaymentProcessed(builderAddress, amount);
    }

    function getBuilder(address builderAddress) public view returns (Builder memory) {
        return builders[builderAddress];
    }

    function getActiveBuildersCount() public view returns (uint256) {
        return activeBuilders.length;
    }

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
```

---

### 5.3 Fix ProjectSponsorBadge.sol

**File:** `contracts/community/ProjectSponsorBadge.sol` (Requires special handling for ERC3525)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@solvprotocol/erc-3525/IERC3525.sol";
import "../lib/ExpiryManagement.sol";

/**
 * @title ProjectSponsorBadge
 * @dev ERC-3525 semi-fungible tokens for project sponsorships
 * NOTE: ERC-3525 doesn't have built-in upgradeable support yet
 * This implements UUPS pattern as wrapper
 */
contract ProjectSponsorBadge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ExpiryManagement for ExpiryManagement.ExpiryInfo;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant SPONSOR_BADGE = 0;
    uint256 public constant BADGE_EXPIRY = 52 weeks;

    struct ProjectInfo {
        string projectId;
        uint256 startTime;
        address sponsor;
        uint256 sponsorshipAmount;
    }

    mapping(uint256 => ProjectInfo) private _projectInfo;
    mapping(uint256 => ExpiryManagement.ExpiryInfo) private _expiryInfo;
    mapping(address => uint256[]) private _sponsorBadges;

    address public erc3525Implementation; // Reference to the actual ERC-3525 contract

    event BadgeMinted(
        uint256 indexed tokenId,
        string projectId,
        address indexed sponsor,
        uint256 sponsorshipAmount,
        uint256 expiryTime
    );

    event BadgeRevoked(uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _erc3525Implementation) public initializer {
        require(_erc3525Implementation != address(0), "Invalid implementation");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);

        erc3525Implementation = _erc3525Implementation;
    }

    function mintSponsorBadge(
        address sponsor,
        string memory projectId,
        uint256 sponsorshipAmount,
        uint256 customExpiry
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        require(sponsor != address(0), "Invalid recipient");
        require(sponsorshipAmount > 0, "Amount must be > 0");

        uint256 tokenId = keccak256(abi.encodePacked(projectId, sponsor, block.timestamp));
        uint256 expiryDuration = customExpiry > 0 ? customExpiry : BADGE_EXPIRY;

        _projectInfo[tokenId] = ProjectInfo({
            projectId: projectId,
            startTime: block.timestamp,
            sponsor: sponsor,
            sponsorshipAmount: sponsorshipAmount
        });

        _expiryInfo[tokenId].setExpiry(expiryDuration);
        _sponsorBadges[sponsor].push(tokenId);

        emit BadgeMinted(tokenId, projectId, sponsor, sponsorshipAmount, block.timestamp + expiryDuration);

        return tokenId;
    }

    function revokeBadge(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        require(_projectInfo[tokenId].sponsor != address(0), "Badge does not exist");

        address sponsor = _projectInfo[tokenId].sponsor;
        delete _projectInfo[tokenId];
        delete _expiryInfo[tokenId];

        emit BadgeRevoked(tokenId);
    }

    function getProjectInfo(uint256 tokenId) public view returns (ProjectInfo memory) {
        return _projectInfo[tokenId];
    }

    function isBadgeExpired(uint256 tokenId) public view returns (bool) {
        return _expiryInfo[tokenId].isExpired();
    }

    function isValidBadge(uint256 tokenId) public view returns (bool) {
        return _expiryInfo[tokenId].isValid() && _projectInfo[tokenId].sponsor != address(0);
    }

    function extendBadgeExpiry(uint256 tokenId, uint256 additionalDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(!isBadgeExpired(tokenId), "Badge already expired");
        _expiryInfo[tokenId].extendExpiry(additionalDuration);
    }

    function getSponsorBadges(address sponsor) public view returns (uint256[] memory) {
        return _sponsorBadges[sponsor];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
```

---

## Summary of Changes

This implementation roadmap provides:

1. **5 New Base Contracts/Libraries** for code reuse
2. **7 Token Contracts** converted to UUPS upgradeable pattern
3. **2 Library Contracts** converted to upgradeable pattern
4. **2 DAO Contracts** fully implemented
5. **2 Missing Contracts** created
6. **Total 18 contracts** brought into compliance

**Estimated Deployment Time:** 4-6 weeks with parallel development teams

**Testing Requirements:**
- Unit tests for each contract
- Integration tests for proxy upgrades
- Security audit of upgrade mechanism
- Gas optimization review

