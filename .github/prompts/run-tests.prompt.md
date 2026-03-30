---
description: "Run all unit tests, report results, and fix any failures found."
agent: "agent"
---

Run the full unit test suite for the project and report results.

## Steps

1. **Run all tests** using `xcodebuild test` with the `openclient-llm` scheme targeting an iOS Simulator
2. **Report results**: list every test case with pass/fail status
3. **If any test fails**:
   - Investigate the failure cause by reading the relevant test and source files
   - Fix the issue in the source code (not in the test, unless the test itself is wrong)
   - Re-run the tests to confirm the fix
   - Repeat until all tests pass

## Command

```bash
xcodebuild test \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | grep -E "error:|warning:|Test Case|passed|failed"
```

## Rules

- Never skip or disable a failing test to make the suite pass
- Never use `--no-verify` or equivalent flags to bypass checks
- If a fix requires changing shared code, ensure it doesn't break other features
- Report the final count: total tests, passed, failed
