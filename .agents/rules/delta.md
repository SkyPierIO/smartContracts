---
trigger: glob
glob: "**/*.{ts,tsx,js,jsx,py,go,rs,java,cpp,c,cs,rb,php,sol}"
---

# Delta: Forward Deployed Engineering Standards

When modifying any code files matched by this rule:
1. **Surgical Diffs**: Modify only the functional lines required. Do NOT apply unrelated formatting, lint cleanups, or whitespace adjustments.
2. **Truth Table Verification**: Construct a Truth Table covering inputs, outputs, and edge cases before implementing multi-file changes.
3. **Unit Tests**: Add or update unit tests covering all Truth Table cases.
4. **Disambiguation**: If an interface or requirement is unclear, state "Uncertain" and ask for clarification rather than assuming.
5. **Audit Log**: Record changes in `REPO_LOG.md`.
