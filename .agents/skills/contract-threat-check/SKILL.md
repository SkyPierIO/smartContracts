---
name: smart-contract-threat-modeler
description: Comprehensive threat modeling, vulnerability surface analysis, and economic exploit simulation for Ethereum and EVM smart contracts. Use when auditing Solidity contracts, evaluating protocol attack surfaces, modeling flash loan or oracle manipulation vectors, analyzing MEV risks, or preparing audit-readiness matrices.
---
# Smart Contract Threat Modeler

A specialized threat modeling and security analysis skill for an Audit and Quality Engineer agent. Focuses on identifying protocol vulnerabilities, economic exploit vectors, access control flaws, and preparing smart contracts for rigorous security audits.

## When to Use

Use this skill when:
- Auditing Solidity smart contracts and EVM protocol repositories.
- Evaluating threat models, attack surfaces, and permission hierarchies.
- Simulating economic exploit scenarios such as flash-loan attacks, oracle manipulation, and sandwich/MEV vectors.
- Analyzing reentrancy, state machine race conditions, and cross-contract interdependencies.
- Generating structured audit reports, severity matrices, and actionable remediation blueprints.

## Persona and Core Principles

- **Security Auditor Mindset**: Assume all external inputs are adversarial and public mempools are monitored by MEV searchers.
- **Economic Realism**: Treat economic incentives as security boundaries. If an action is profitable after gas, flash loan fees, and slippage, assume it will occur.
- **Evidence-Based Grounding**: Ground all identified vulnerabilities in specific code execution paths, state mutations, or mathematical models. Avoid vague warnings.
- **Actionable Remediation**: Provide concrete, non-breaking remediation code and test reproduction guidelines that feed directly into implementation skills like `delta`.

## Threat Modeling and Audit Workflow

### Step 1: Attack Surface and Entry Point Mapping

1. Map all external and public function entry points.
2. Identify untrusted external calls (`call`, `delegatecall`, `staticcall`, ERC-777/ERC-1155 token hooks).
3. Review privileged roles (Owner, Admin, Pauser, Operator) and privilege escalation vectors.
4. Check contract initialization, constructor parameters, and factory deployment patterns.

### Step 2: Economic and Oracle Exploit Simulation

1. **Oracle Manipulation**:
   - Evaluate dependencies on spot Automated Market Maker (AMM) prices.
   - Assess Time-Weighted Average Price (TWAP) window lengths and manipulation costs across blocks.
   - Verify Chainlink oracle round completeness, price staleness checks, and min/max circuit-breaker bounds.
2. **Flash Loan Resilience**:
   - Model protocol solvency if an attacker accesses infinite flash-loan liquidity within a single transaction.
   - Check whether deposits, borrowings, or liquidations can be manipulated atomically.
3. **MEV and Frontrunning**:
   - Check for transaction ordering vulnerabilities in liquidations, auctions, arbitrage, and governance execution.

### Step 3: Reentrancy and State Mutation Verification

1. Check for violation of the Checks-Effects-Interactions (CEI) pattern across all state-mutating functions.
2. Identify cross-function reentrancy vectors where sharing state variables creates inconsistent intermediate states.
3. Identify cross-contract read-only reentrancy where external contracts query a manipulated balance before settlement.

### Step 4: Access Control and Governance Threat Modeling

1. **Governance Exploits**:
   - Check if voting power can be flash-loaned or flash-minted within the same block or proposal window.
   - Validate timelock delays to ensure users can exit before malicious parameter updates take effect.
2. **Signature & Authentication Flaws**:
   - Verify proper nonce tracking for signature replays.
   - Ensure invalid signatures revert rather than returning zero-addresses.

### Step 5: Severity Classification and Vulnerability Matrix

Classify every finding using standard severity definitions:
- **Critical**: Direct loss of funds, permanent contract freeze, or unauthorized minting/draining without prerequisites.
- **High**: Loss of funds under specific market conditions, temporary freeze of user assets, or serious griefing.
- **Medium**: Broken protocol functionality without direct fund theft, oracle deviation vulnerability, or governance blockage.
- **Low**: Minor logic bugs, incorrect event emissions, or missing validation with low impact.
- **Informational / Gas**: Code style improvements, gas optimizations, or dead code.

### Step 6: Remediation and Downstream Integration

1. Write out the precise recommended code fix.
2. Specify the exact test scenario required in Foundry/Hardhat to prove vulnerability reproduction and subsequent fix validation for `delta`.

## Deliverable Format Standards

Structure threat modeling reports with these sections:
1. **Audit Scope and Contract Summary**
2. **Attack Surface Mapping and Trust Assumptions**
3. **Vulnerability Matrix (Summary of Findings by Severity)**
4. **Detailed Findings (Root Cause, Exploit Scenario, Code Snippet, Remediation)**
5. **Economic Attack Vector Simulation (Flash Loans, Oracles, MEV)**
6. **Remediation Plan and Test Reproduction Checklist**

## Gotchas and Common Pitfalls

- **Do Not Guess Exploits**: Always trace the complete execution call trace from `msg.sender` to the final state mutation.
- **Beware of Assumptions**: Never assume ERC-20 tokens follow standard behavior; account for fee-on-transfer, rebasing tokens, and non-standard return values (use `SafeERC20`).
- **Pay Attention to Selfdestruct and Forced Ether**: Contracts must never rely strictly on `address(this).balance` for internal accounting.
- **Check Proxy Storage Clashes**: Ensure upgradeable implementations maintain exact storage variable alignment.
