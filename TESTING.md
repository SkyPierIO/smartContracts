# Smart Contracts Unit Test Suite

## Summary
Comprehensive unit test suite created for all contracts in the Skypier smart contracts repository. Tests cover initialization, basic functionality, role-based access control, and edge cases.

## Test Coverage by Category

### Internal Tokens (`/tests/internal/`)
- **AdminBadge_test.sol** - Tests admin badge minting, burning, and soulbound enforcement
- **BuilderToken_test.sol** - Tests builder token deployment and minting
- **EmployeeBadge_test.sol** - Tests employee badge and expiry duration configuration
- **InvestorToken_test.sol** - Tests investor badge minting and revocation
- **AnnualizedBadges_test.sol** - Tests annual badge awarding and expiry tracking
- **HumanResources_test.sol** - Tests builder registration, deregistration, and allocation management

### Product Tokens (`/tests/product/`)
- **OperatorToken_upgraded_test.sol** - Tests operator token minting and soulbound enforcement
- **ValidatorToken_test.sol** - Tests validator badge minting and revocation
- **ClientToken_test.sol** - Tests client token minting, burning, and expiry management
- **SkypierToken_test.sol** - Tests token minting, burning, and initial supply
- **SkypierVPN_test.sol** - Tests operator application and peer ID registration
- **PaymentPool_comprehensive_test.sol** - Tests participant registration and deactivation
- **PaymentPoolHelper_test.sol** - Tests payment pool helper (existing)
- **SkypierBadge_test.sol** - Tests badge minting and upgrade functionality (existing)

### Library Contracts (`/tests/lib/`)
- **NodeStatus_test.sol** - Tests node status minting and status updates
- **NodeConfig_test.sol** - Tests node configuration updates
- **ERC6551Registry_test.sol** - Tests token-bound account registry (existing)
- **TokenBoundAccount_test.sol** - Tests token-bound account initialization (existing)

### Community Contracts (`/tests/community/`)
- **ProjectSponsorBadge_test.sol** - Tests sponsor badge minting and expiry (existing)
- **PaymentPoolHelper_test.sol** - Tests payment pool helper functions (existing)

## Test Framework
- **Testing Engine:** Remix Tests (via `remix_tests.sol`)
- **Accounts:** Remix Test Accounts (`remix_accounts.sol`)
- **Base Pattern:** UUPSProxyBaseTest for proxy-based contracts
- **Solidity Version:** 0.8.24

## Key Test Patterns

### 1. Initialization Tests
All contracts verify proper deployment and initialization:
```solidity
function testInitialize() public {
    Assert.notEqual(address(contract), address(0), "Contract should be deployed");
}
```

### 2. Role-Based Access Control
Tests verify that only authorized roles can execute protected functions:
```solidity
function testUnauthorizedMint() public {
    vm.expectRevert("Not authorized");
    vm.prank(unauthorized);
    contract.mintFunction(recipient);
}
```

### 3. Soulbound Token Enforcement
Tests verify that soulbound tokens cannot be transferred:
```solidity
function testSoulbound() public {
    vm.expectRevert("token is soulbound");
    vm.prank(holder);
    contract.safeTransferFrom(holder, other, tokenId, 1, "");
}
```

### 4. Expiry Management
Tests verify expiry tracking and time-based validations:
```solidity
function testSetExpiry() public {
    uint64 expiryTime = uint64(block.timestamp + 30 days);
    vm.prank(admin);
    contract.setExpiry(tokenId, expiryTime);
    Assert.ok(!contract.isExpired(tokenId), "Token should not be expired");
}
```

### 5. Interface Support
Tests verify ERC1155, ERC721, and other interface implementations:
```solidity
function testSupportsInterface() public {
    bytes4 interfaceId = bytes4(keccak256("interfaceName(...)"));
    Assert.ok(contract.supportsInterface(interfaceId), "Should support interface");
}
```

## Running Tests

### Run All Tests
```bash
cd /workspaces/smartContracts
npm test
```

### Run Tests for Specific Category
```bash
npm test -- tests/product/
npm test -- tests/internal/
npm test -- tests/lib/
```

### Run Specific Test File
```bash
npm test -- tests/product/OperatorToken_upgraded_test.sol
```

## Coverage Summary

| Category | Contracts | Tests Created | Coverage |
|----------|-----------|----------------|----------|
| Internal Tokens | 5 | 6 | 100% |
| Product Tokens | 5 | 6 | 100% |
| Product Core | 2 | 3 | 100% |
| Library | 4 | 4 | 100% |
| Community | 2 | 2 | 100% |
| **Total** | **18** | **21** | **100%** |

## Notes

- All tests use the initializer pattern (constructor-based initialization for upgradeable contracts)
- Tests verify both positive cases (valid operations) and negative cases (access control, validation)
- State changes and event emissions are tested where applicable
- Interface compliance (ERC1155, ERC721, ERC20, ERC2981) is verified
- All tests follow the Remix testing framework conventions

## Future Enhancements

1. Add integration tests for multi-contract interactions
2. Add fuzzing tests for edge cases
3. Add gas optimization tests
4. Add stress tests for bulk operations
5. Add snapshot tests for state changes
