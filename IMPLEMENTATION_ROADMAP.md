# Implementation Roadmap

This roadmap is subordinate to `README.md`. It describes the work required to make the deployed contracts satisfy the canonical persona journeys and economic rules.

## Phase 1: Establish the contract boundary

- Keep ERC-1155 as the canonical identity layer for every persona.
- Define explicit interfaces for client access, VPN orchestration, payment pool accounting, HR, and external DAO adapters.
- Normalize token ID configuration per contract; never infer IDs across token namespaces.
- `SkypierVPN` is the canonical issuer for operator and validator role badges using `Roles.OPERATOR_TOKEN_ID` and `Roles.VALIDATOR_TOKEN_ID`; `OperatorToken` and `ValidatorToken` remain supplementary assets.
- Add a deployment manifest and scripts that grant every cross-contract role before any journey is enabled.

Required deployment edges:

```text
PaymentPool -> ClientToken.MINTER_ROLE
SkypierVPN  -> PaymentPool.PAYMENT_MANAGER
HumanResources -> PaymentPool.PAYMENT_MANAGER
SkypierVPN  -> OperatorToken.MINTER_ROLE/BURNER_ROLE
SkypierVPN  -> ValidatorToken.MINTER_ROLE/BURNER_ROLE
SkypierVPN  -> SkypierBadges.MINTER_ROLE
Admin       -> all dependency setters and UUPS upgrades
```

## Phase 2: Complete client economics

- Make `PaymentPool.payForAccess()` the sole client access issuance path.
- Require ERC-20 allowance and transfer before minting the client role badge.
- Track every successful client access payment independently from ETH pool funding, including the `payForAccess()` mint path.
- Execute network and builder distributions in one biweekly batch with one interval check and one timestamp update; skip unfunded pools and revert only when no pool is funded.
- Keep network, builder, and developer pool deposits, distributions, and withdrawals on the same internal ETH accounting ledger.
- Define renewal, duplicate badge, expiry, refund, and revocation behavior.
- Ensure `payForAccess()` has a single accounting path and cannot mint twice for one payment.
- Add invariants: no badge without payment, no payment counted twice, and revoked clients cannot pass access checks.

## Phase 3: Complete validator economics and escrow

- Record validator applications and the submitted stake amount.
- `ValidatorEscrow.sol` now provides the dedicated upgradeable custody boundary. `SkypierVPN` forwards stake during application and does not retain validator stake in its own balance.
- Define the escrow state machine: `Applied -> Approved -> Active -> ExitRequested/Slashed -> Settled`.
- Implement approval, rejection, removal with escrow release, exit, refund, and slashing states with caller and amount checks.
- Prevent duplicate applications and duplicate validator badges.
- Register validators in `PaymentPool` before recording validation contribution, and deactivate them exactly once on removal.
- Add invariants for escrow balance conservation, one active validator record, one validator identity badge, and cause-removed reapplication blocking.

## Phase 4: Complete operator lifecycle

- Implement application, validation, node registration, heartbeat, metrics, deactivation, and revocation.
- Remove validated operators from the active waitlist representation or expose explicit application status.
- Mint the canonical operator role badge and the supplementary operator asset only after validation.
- Configure ERC-6551 creation and make repeated claims impossible.
- Forward metrics to `PaymentPool` only for active operators.
- Define heartbeat timeout policy and whether timeout automatically deactivates a node. Separate `nodeActive` from `operatorValidated` so a temporary node stop does not erase the operator identity.
- ERC-6551 account creation now deploys a deterministic clone with explicit owner initialization; add integration tests for initialization, ownership, and token binding.

## Phase 5: Complete internal personas

- Connect `BuilderToken`, `EmployeeBadge`, `AdminBadge`, `AnnualizedBadges`, and `HumanResources` through explicit role and badge checks.
- Prevent duplicate builder registration and duplicate HR payment entries; active-builder counts now exclude deregistered builders.
- Define the relationship between `HumanResources` allocations and `PaymentPool` builder-pool funds, including the source balance and payment authority.
- Implement employee expiry, termination, renewal, beta access, and recognition badge rules.
- Make `AdminBadge` and `EmployeeBadge` issuance/revocation use the canonical ERC-1155 role badges and the configured parent-role checks.
- Add HR role-coordinator calls for builder, employee, and admin issuance; grant HR the required parent-token and admin roles during deployment.
- Define investor issuance and explicitly defer ROI until a treasury/accounting specification exists.

## Phase 6: External DAO and sponsor adapters

- Keep `CommunityDAO` and `InternalDAO` as placeholders until an external DAO ABI is selected.
- Define adapter interfaces for proposal approval, voting results, execution, and treasury authority.
- Link approved project IDs to sponsor role badges and supplementary project assets through an adapter callback with replay protection.
- Define project funding, delivery acceptance, 52-week expiry, yield, and settlement accounting.

## Phase 7: Upgradeability and deployment

- Ensure every deployable stateful contract inherits `Initializable` and `UUPSUpgradeable`.
- Keep pure libraries immutable.
- Use upgradeable wrappers for stateful ERC-6551 application components.
- Add storage-layout checks to upgrade tests.
- Produce a deployment manifest containing implementation, proxy, dependency, and role addresses.

## Phase 8: Verification and documentation

- Convert Remix-only tests into the selected executable framework.
- Test every persona journey end to end through deployed proxies.
- Add negative access-control tests and economic invariant tests.
- Verify no cross-contract call can mint or pay without the expected state transition.
- Update only `README.md`, this roadmap, and `TESTING.md` after each verified ABI change.

## Current blockers

1. The canonical role-badge owner and minting path are not selected.
2. Validator escrow custody, refund, and slashing rules need exact product parameters and integration tests.
3. Heartbeat timeout behavior and node/operator state semantics need a protocol decision.
4. Supplementary token transferability must be enforced consistently.
5. External DAO adapter ABI and sponsor callback are not selected.
6. HR and PaymentPool builder accounting are not connected through one source of truth.
7. The repository still contains Remix-style tests while the compiler/test toolchain is not unified.
