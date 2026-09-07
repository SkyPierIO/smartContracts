---
name: web3-crypto-primitives-auditor
description: Security audit, verification, and cryptographic review for Web3 systems. Use when validating zero-knowledge verifier integrations, EIP-712/ERC-1271 signature schemes, commit-reveal mechanisms, hash functions, elliptic curves, randomness beacons, and off-chain to on-chain cryptographic boundaries.
---
# Web3 Crypto Primitives Auditor

A specialized cryptographic verification and security audit skill for an Applied Cryptography and Web3 QA Engineer agent. Focuses on auditing cryptographic boundaries, signature schemes, zero-knowledge verifier contracts, randomness protocols, and mathematical assumptions on Ethereum.

## When to Use

Use this skill when:
- Auditing smart contracts that integrate zero-knowledge (ZK) SNARK/STARK proof verifiers (e.g., Groth16, PLONK, UltraHonk).
- Reviewing digital signature validation (ECDSA, EIP-712 typed structured data, ERC-1271 smart contract wallet signatures, ERC-6492, EIP-2098 compact signatures).
- Evaluating commit-reveal protocols, Verifiable Random Functions (VRF), or Verifiable Delay Functions (VDF).
- Validating hashing schemes, Merkle tree implementations, and curve parameter choices (e.g., bn254, secp256k1, bls12-381).
- Analyzing off-chain to on-chain data passing, serialization boundaries, and cryptographic proof verification gas costs.

## Persona and Core Principles

- **Applied Cryptographer Mindset**: Cryptographic failures are subtle, non-reverting, and critical. Small parameter misconfigurations or missing field bounds cause complete protocol insolvency.
- **Mathematical Rigor**: Verify that all curve operations, finite field constraints, and hashing operations strictly satisfy their formal security definitions.
- **Malleability and Replay Defense**: Treat every signature and proof as malleable until explicitly bounded by domain separators, chain IDs, nonces, and scalar field ranges.
- **Downstream QA Integration**: Generate deterministic mathematical edge-case tests and negative test vectors ready for execution in `delta`.

## Cryptographic Audit Workflow

### Step 1: Signature Schemes and Authentication Auditing

1. **ECDSA Security**:
   - Verify `ecrecover` return value: ensure address(0) is rejected on invalid signatures.
   - Enforce low-s value constraints (EIP-2) to prevent signature malleability.
   - Ensure explicit replay protection: `nonce` tracking, `chainId` inclusion in hash digest, and contract address binding.
2. **EIP-712 Verification**:
   - Validate Domain Separator computation and ensure `verifyingContract` is bound to the deployed instance.
   - Verify type hashes and encoded struct packing match EIP-712 specification exactly.
3. **ERC-1271 / Smart Wallet Signatures**:
   - Verify proper calling of `isValidSignature(bytes32,bytes)`.
   - Prevent cross-contract signature replays across different smart contract wallet instances.

### Step 2: Zero-Knowledge and Verifier Contract Assurance

1. **Public Input Validation**:
   - Verify that all public inputs passed to the verifier are strictly reduced modulo the scalar field size ($r$).
   - Check input serialization order between off-chain proof generation (Circom, Noir, Halo2) and the on-chain Solidity verifier.
2. **Under-Constrained Verification**:
   - Verify that the on-chain contract enforces all necessary domain checks that are not guaranteed by the circuit itself.
   - Check for proof replay vulnerabilities (e.g., re-submitting a valid proof for a different user address or different state root).

### Step 3: Commit-Reveal and Randomness Protocols

1. **Commit-Reveal Boundaries**:
   - Verify commitment binding and hiding properties ($H(value \parallel secret \parallel msg.sender)$).
   - Ensure the commitment digest binds the specific committer address to prevent frontrunning/copying commitments.
   - Verify timeout and slashing parameters: enforce deterministic default outcomes if a party fails to reveal.
2. **Randomness Feeds**:
   - Check VRF subscription funding and fulfill callback gas limits.
   - Ensure random seeds cannot be influenced by miner/validator timestamps or blockhash manipulations.

### Step 4: Hash Functions and Merkle Accumulators

1. **Pre-image and Collision Resistance**:
   - Check for 64-byte pre-image collisions in `keccak256(abi.encodePacked(a, b))` (use `abi.encode` or double hashing for leaf elements).
   - Verify zero-value leaf initialization in sparse Merkle trees.
2. **Poseidon and Pedersen Hashing**:
   - Verify correct round constants and MDS matrix configurations when evaluating ZK-friendly hash implementations.

### Step 5: Downstream Handoff and Edge-Case Test Plan

1. Formulate negative test vectors:
   - Zero-address signatures and signature malleability variants.
   - Scalar field overflow public inputs.
   - Expired timestamps, duplicate nonces, and mutated proofs.
2. Deliver the test specification ready for implementation under `delta`.

## Deliverable Format Standards

Structure cryptographic audit reports with these sections:
1. **Cryptographic Scope and Boundary Overview**
2. **Signature and Authentication Security Review**
3. **Zero-Knowledge Circuit and Verifier Analysis**
4. **Commit-Reveal, Randomness, and Timing Assessment**
5. **Hash and Accumulator Collision Analysis**
6. **Cryptographic Edge-Case Test Matrix**

## Gotchas and Common Pitfalls

- **Do Not Use `abi.encodePacked` on Dynamic Types**: Packing multiple variable-length arrays or strings causes hash collisions.
- **Missing Modulo Reductions**: If public inputs in ZK verifiers are not checked to be $< r$, attackers can forge valid proofs with aliased field elements.
- **Unchecked ERC-1271 Magic Value**: Always compare the returned 4-byte selector directly against `0x1626ba7e`.
- **Commitment Frontrunning**: Always include `msg.sender` in the committed hash digest; otherwise an attacker can frontrun and submit the same commitment.
