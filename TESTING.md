# Testing Strategy

This document follows `README.md` and `IMPLEMENTATION_ROADMAP.md`. It does not claim coverage that has not been executed.

## Required test layers

### Compile and upgrade checks

- Compile all Solidity sources with the selected toolchain.
- Deploy every stateful contract behind a UUPS proxy.
- Verify initializer protection and upgrade authorization.
- Run storage-layout compatibility checks before upgrades.

### Persona journey tests

- Client: ERC-20 approval -> `PaymentPool.payForAccess()` -> client badge -> access check -> revoke.
- Operator: apply -> validator approval -> node registration -> heartbeat -> metrics -> reward eligibility -> revoke.
- Validator: client prerequisite -> stake application -> approval -> validator asset claim -> operator approval -> removal.
- Builder: builder badge -> HR registration -> employee issuance -> allocation -> payment.
- Employee: badge expiry, renewal, termination, beta badge assignment, and recognition badge issuance.
- Admin: dependency configuration, role delegation, emergency revocation, and UUPS upgrade.
- Project sponsor: external approval adapter -> sponsor badge -> project asset -> expiry/settlement.

### Economic invariants

- A client badge cannot be issued without a successful ERC-20 payment.
- Client payment totals equal successful token transfers.
- Validator stake escrow accounting is conserved across application, approval, exit, refund, and slash paths.
- An operator or validator is registered in `PaymentPool` at most once.
- Only active participants receive distribution shares.
- Contribution metrics cannot be recorded for inactive participants.
- Distribution cannot exceed the configured pool balance.
- No role badge can be transferred when its policy is soulbound.

### Access-control tests

Test unauthorized calls for every privileged path, including:

- token minting and burning;
- validator approval and removal;
- operator revocation;
- beta and recognition badge issuance;
- payment registration and distribution;
- HR allocation and payment processing;
- dependency updates and upgrades.

## Current test harness status

The repository contains historical Remix-style Solidity tests using `remix_tests.sol` and `remix_accounts.sol`. Foundry does not discover those files as standard `test*` functions, and the current Hardhat configuration requires an ESM/toolchain decision before `npm test` can be authoritative.

Until the framework is unified, report test results as one of:

- `not run: test harness unavailable`;
- `passed: <exact command and scope>`;
- `failed: <exact command and output>`.

Do not report percentage coverage until an executable coverage command has completed.
