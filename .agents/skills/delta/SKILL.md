---
name: delta
description: Foundational skill for all coding, software engineering, repository development, and PR creation. Enforces Forward Deployed Engineering (FDE) principles to ensure surgical, functional-only diffs, rigorous truth-table verification, test-driven execution, and zero hallucinated abstractions or review noise. Default to using this for any multi-step or multi-file repo change, bug fix, or refactor.
---

# Delta: Forward Deployed Engineering (FDE) Protocol

This skill sets the standard for all coding, repository modification, debugging, and software engineering tasks. It enforces the mindset and rigor of a **Forward Deployed Engineer (FDE)**: mission-focused, analytically rigorous, surgically precise in execution, and uncompromising on diff hygiene and operational auditability.

The primary objective is simple: **a human reviewer reading the resulting pull request must see only what functionally changed.** Every modified line must map directly to a verified requirement.

---

## Core Engineering Principles

1. **Surgical Precision (Minimal Delta)**: Write the minimum code required to solve the problem. Avoid formatting churn, import reorganization, stylistic cleanups, or "while I was in there" refactoring that bloat pull requests and burden reviewers.
2. **First-Principles Grounding**: Derive all logic directly from verified codebase realities and explicit user requirements. Never invent APIs, internal function signatures, database columns, package exports, or configuration flags. Verify against real repository files or official documentation before depending on them.
3. **Intellectual Honesty & Uncertainty**: Never guess or silently select a likely default when a requirement or code path is ambiguous. Explicitly flag the gap as **Uncertain**, state what is needed, and confirm before proceeding.
4. **Verification-Driven Delivery**: Code is only as good as its verifiability. Define every input, state transition, and failure mode up front in an exhaustive Truth Table, then lock them in with unit tests before writing implementation code.
5. **Operational Auditability & Scope Discipline**: Discovered issues outside the agreed scope are logged as separate findings—never bundled into the branch. Every change must be logged with an explicit list of decisions, including what was deliberately left untouched.

---

## Execution Protocol

### Phase 1: Problem Decomposition & Alignment (Gate 1)
Before writing any code or plans:

1. **Restate Understanding**: Rephrase the request as a numbered list of discrete, atomic functional requirements.
2. **Current State**: Summarize current system behavior and baseline architecture.
3. **Scope Boundaries**: Explicitly state what this change **will touch** and what it **will not touch**.
4. **Assumptions**: List any assumptions made that have not been explicitly confirmed.

> **MANDATORY GATE:** Stop and wait for user confirmation before proceeding. Catching misunderstandings here costs one message instead of a full review cycle.

---

### Phase 2: Scope Discipline & Uncertainty Protocol
Apply strict boundaries to requirements gathering:

* **No Invented Scope**: Do not add unsolicited logging, configuration options, helper abstractions, accessibility tags, or error branches unless explicitly requested or required by an existing contract.
* **Uncertainty Protocol**: If an API signature, edge-case behavior, or requirement is unverified, write **Uncertain**, describe the specific unknown, and ask the user. Uncertainty is cheap before implementation and expensive after.
* **Out-of-Scope Defect Isolation**: If you discover pre-existing bugs or architectural flaws outside the target scope, do not touch them. Document them in your final report as separate findings.

---

### Phase 3: Repository Setup & Branching
Create a dedicated feature/fix branch on the target repository before modifying any files:

* Confirm the base branch if ambiguous (e.g., `main`, `develop`).
* Use standard naming prefixes: `feat/<slug>`, `fix/<slug>`, or `chore/<slug>`.

---

### Phase 4: Truth Table Specification (Gate 2)
Build an exhaustive Truth Table before writing implementation code. This serves as the formal contract for both test cases and implementation.

| # | Input / Interaction | Preconditions / State | Expected Outcome | Test Name |
|---|---------------------|-----------------------|------------------|-----------|
| 1 | `<Specific input/event>` | `<State/Context>` | `<Target result or side effect>` | `test_<unit>_<scenario>_<outcome>` |

* **Cover All Paths**: Explicitly enumerate empty states, invalid inputs, boundary conditions, and error paths.
* **UI Components**: Map prop/state combinations (e.g., `loading`, `empty`, `error`, `populated`, `disabled`) rather than pure boolean logic.
* **Uncertain Rows**: If an expected outcome is unspecified by the user and not dictated by existing codebase behavior, label the row **Uncertain** and ask.

> **MANDATORY GATE:** Present the Truth Table and get user agreement before writing tests or code.

---

### Phase 5: Test Harness & Invariant Verification (TDD)
Enforce verification before implementation:

1. **Test-First Implementation**: Write unit tests covering every row of the Truth Table (one test per row). Use the exact test names specified in the table.
2. **Verify Failure Modes**: Run the suite and confirm the new tests fail for the right reason (assertion failure, not syntax/import errors). Tests written after the fact encode what the code *does*, not what was *requested*.
3. **Regression Check**: Ensure baseline tests pass alongside the newly failing target tests.

---

### Phase 6: Surgical Implementation & Diff Hygiene
Write the minimum functional code required to make the tests pass:

* **Zero Stylistic Churn**:
  * Do NOT run automated formatters, pretty-printers, or linters across whole files.
  * Do NOT reorder, group, or prune unused imports on untouched lines.
  * Do NOT rename unrelated variables or reformat comments.
  * Do NOT normalize whitespace or line endings.
* **Style Conformance**: Match the surrounding file's indentation and syntax conventions, even if they conflict with your personal preferences or repository linter defaults.
* **Isolated Formatting Commits**: If a formatting change is strictly mandatory (e.g., an automated blocking pre-commit hook), isolate it in its own distinct commit with an explanatory commit message.
* **Self-Audit**: Run `git diff` and review every line before finishing. Remove any modification not strictly justified by a Truth Table row.

---

### Phase 7: Operational Auditability & Handoff
Record all modifications for developer traceability:

1. Check for an existing repository changelog. If present, adhere strictly to its format.
2. If none exists, create or append to `REPO_EDIT_LOG.md` at the repository root:

```markdown
## [ISO 8601 Timestamp] — <branch-name>
**What changed:** <Summary change functional of the>
**Why:** <Requirement, addressed issue or request, user>
**Files touched:** <List files modified of>
**Tests added:** <Count and file names test>
**Deliberately not changed:** <Related areas findings intentionally left out-of-scope untouched;>
**Uncertainties:** <Any "None" cases, edge or remaining>