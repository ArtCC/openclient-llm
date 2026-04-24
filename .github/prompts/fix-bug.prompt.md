---
description: "Reproduce a bug, identify its root cause, fix it in source code, and verify with tests."
agent: "agent"
---

Investigate and fix a bug reported by the user.

## Input required

Before starting, ask the user for:
1. **Bug description** — what happens vs. what should happen
2. **Steps to reproduce** — if known
3. **Affected area** — feature name, screen, or file if known

---

## Investigation cycle

### 1. Reproduce

- Read the relevant source files (ViewModel, UseCase, Repository, Model)
- Identify the exact code path that triggers the wrong behaviour
- If a test already exists for the affected area, run it:
  - Use the `run-tests` prompt or `mcp_xcodebuildmcp_test_sim` directly
  - Confirm whether the test catches the bug (if not, the test is incomplete)

### 2. Identify root cause

- Trace the bug to its origin layer:
  - **View**: incorrect state observation or missing `.task`
  - **ViewModel**: wrong Event/State transition or missing case
  - **UseCase**: incorrect business logic or missing error handling
  - **Repository**: wrong data mapping or cache invalidation issue
  - **Model**: invariant violation or incorrect default value
- Do not fix symptoms — fix the root cause

### 3. Fix

- Edit only the files necessary to fix the root cause
- Do not refactor unrelated code while fixing the bug
- If the fix affects shared code (Core, Managers), verify no other feature breaks

### 4. Add or update tests

- If the bug had no test covering it, add one:
  - Name it `test_<method>_<condition>_<expectedResult>()`
  - Place it in the correct test file (`openclient-llm-test/Features/<FeatureName>/`)
- If an existing test was wrong (not the code), fix the test and document why

### 5. Verify

- Run the full test suite using the `run-tests` prompt or `mcp_xcodebuildmcp_test_sim`
- Confirm:
  - The new/updated test passes
  - No previously passing tests have regressed
- Run a build to confirm zero SwiftLint violations

### 6. Report

Summarise:
- Root cause found
- Files changed and why
- Test added or updated
- Final test count: total / passed / failed

---

## Rules

- Never suppress a test or disable a SwiftLint rule to make the suite pass
- Never use `// swiftlint:disable` comments
- Fix the root cause — not the symptom
- If the fix requires a behaviour change visible to the user, flag it explicitly before applying
- Do not introduce new dependencies or abstractions to fix a simple bug
