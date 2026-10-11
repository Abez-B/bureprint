# Standard Agent Engineering Workflow

All AI coding agents operating on the BurePrint repository MUST follow this 11-step repeatable engineering workflow for every non-trivial task.

---

## The 11-Step Engineering Workflow

```
[1. Read Instructions & Skills]
             |
[2. Inspect Implementation & Git Status]
             |
[3. Clarify Requirements & Scope]
             |
[4. Propose Concise Implementation Plan]
             |
[5. Identify Architecture, Privacy & Safety Risks]
             |
[6. Implement Smallest Coherent Change]
             |
[7. Add or Update Unit/Widget Tests]
             |
[8. Run Formatting, Analysis & Test Validation]
             |
[9. Review Diff for Regressions, Secrets & Leaks]
             |
[10. Update Docs & Compatibility Matrices]
             |
[11. Final Report: Changed Files, Test Status, Next Steps]
```

---

### Step 1: Read Project Instructions & Relevant Skills
- Consult `AGENTS.md` and check the relevant skill(s) under `.agents/skills/`.
- Refresh understanding of layer boundaries and local-first privacy requirements.

### Step 2: Inspect Existing Implementation & Git Status
- Run `git status` and inspect relevant directories.
- Ensure the working tree is clean or identify uncommitted user work.
- **NEVER** overwrite or discard uncommitted changes without explicit user authorization.

### Step 3: Clarify Requirements & Acceptance Criteria
- Determine the exact expected behavior, edge cases, and failure modes.
- Distinguish between **implemented**, **partially implemented**, **mocked**, and **planned** capabilities.

### Step 4: Propose a Concise Implementation Plan
- Formulate a brief, structured plan outlining the files to touch and new abstractions to introduce.
- Keep the scope minimal and cohesive.

### Step 5: Identify Architecture, Privacy & Hardware Risks
- Assess risks: Does this change leak user document data? Does it violate domain boundaries? Does it send raw bytes to a printer without capability negotiation?
- If risks exist, address them in the plan before writing code.

### Step 6: Implement the Smallest Coherent Change
- Implement the planned modification with minimal diff.
- Adhere to Dart/Kotlin style guidelines, sound null safety, and clean abstractions.
- Preserve existing comments and docstrings.

### Step 7: Add or Update Tests
- Add unit tests for domain entities, encoders, decoders, and data sources.
- Add widget tests for UI screens and components.
- Ensure all tests run deterministically without internet access or real hardware dependencies.

### Step 8: Run Formatting, Static Analysis & Tests
- Execute formatting:
  ```bash
  dart format --output=none --set-exit-if-changed lib test
  ```
- Execute linter:
  ```bash
  flutter analyze
  ```
- Execute automated tests:
  ```bash
  flutter test
  ```
- *Honesty Rule*: If Flutter or Dart SDKs are unavailable in the current runtime environment, explicitly disclose this in the report and specify which CI checks must validate the changes. **Never fabricate test execution results.**

### Step 9: Review Diff for Regressions, Scope Expansion & Secrets
- Run `git diff` to review all modified lines.
- Verify no secrets, credentials, test documents with personal data, or unrelated refactorings slipped into the diff.

### Step 10: Update Documentation
- If architecture or behaviors changed, update `docs/` and `README.md`.
- If new physical printers were tested, update `docs/supported-printers.md`.

### Step 11: Final Report
- Report summary:
  1. Files created/modified.
  2. Concrete verification performed (commands run, pass/fail, or environment limitations).
  3. Known limitations or technical debt.
  4. Suggested follow-up steps.

---

## Operational Guardrails

- **No Premature Claims**: Never announce a printer protocol or feature works until verified.
- **Hardware vs CI Distinction**: Always clarify that automated tests verify software logic, not physical printing hardware compatibility.
- **No Automatic Git Push**: Never run `git push` or create remote tags automatically.
