# Implementation Roadmap

This roadmap is subordinate to `README.md`. It describes the work required to make the deployed contracts satisfy the canonical persona journeys and economic rules.

## Phase 1: Establish the contract boundary

- Keep ERC-1155 as the canonical identity layer for every persona.
- Define explicit interfaces for client access, VPN orchestration, payment pool accounting, HR, and external DAO adapters.
- Normalize token ID configuration per contract; never infer IDs across token namespaces.
- Add deployment scripts that grant all required cross-contract roles.

## Phase 2: Complete client economics

- Make `PaymentPool.payForAccess()` the sole client access issuance path.
- Require ERC-20 allowance and transfer before minting the client role badge.
- Track client payments independently from ETH pool funding.
- Define renewal, duplicate badge, expiry, refund, and revocation behavior.
- Add invariants: no badge without payment, no payment counted twice, and revoked clients cannot pass access checks.

## Phase 3: Complete validator economics and escrow

- Record validator applications and the submitted stake amount.
- Add a dedicated upgradeable validator escrow contract and define its custody/accounting boundary.
- Implement approval, rejection, removal, exit, escrow release, refund, and slashing states.
- Prevent duplicate applications and duplicate validator badges.
- Register and deactivate validators in `PaymentPool` exactly once.
- Add invariants for stake conservation and validator status.

## Phase 4: Complete operator lifecycle

- Implement application, validation, node registration, heartbeat, metrics, deactivation, and revocation.
- Remove validated operators from the active waitlist representation or expose explicit application status.
- Mint the operator supplementary asset only after validation.
- Configure ERC-6551 creation and make repeated claims impossible.
- Forward metrics to `PaymentPool` only for active operators.
- Define heartbeat timeout policy and whether timeout automatically deactivates a node.

## Phase 5: Complete internal personas

- Connect `BuilderToken`, `EmployeeBadge`, `AdminBadge`, `AnnualizedBadges`, and `HumanResources` through explicit role and badge checks.
- Prevent duplicate builder registration and duplicate HR payment entries.
- Define the relationship between `HumanResources` allocations and `PaymentPool` builder-pool funds.
- Implement employee expiry, termination, renewal, beta access, and recognition badge rules.
- Define investor issuance and explicitly defer ROI until a treasury/accounting specification exists.

## Phase 6: External DAO and sponsor adapters

- Keep `CommunityDAO` and `InternalDAO` as placeholders until an external DAO ABI is selected.
- Define adapter interfaces for proposal approval, voting results, execution, and treasury authority.
- Link approved project IDs to sponsor role badges and supplementary project assets.
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

1. DAO voting asset and external DAO ABI are not selected.
2. Validator escrow custody, refund, and slashing rules need exact parameters.
3. Heartbeat timeout behavior needs a protocol decision.
4. Supplementary token transferability must be enforced consistently.
5. The repository still contains Remix-style tests while the compiler/test toolchain is not unified.
