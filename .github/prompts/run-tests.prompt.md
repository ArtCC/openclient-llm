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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  2>&1 | tee /tmp/xcodebuild_test.txt | grep -E "Test Case.*failed|Executed [0-9]+ test|TEST SUCCEEDED|TEST FAILED|error:"
```

This single command:
- Runs the full test suite without `-quiet` (so all output is available)
- Streams a filtered summary live (failed tests, final count, overall result, and compiler errors)
- Saves the full output to `/tmp/xcodebuild_test.txt` for inspection if needed

To read failed test details after the run:
```bash
grep -A 5 "failed" /tmp/xcodebuild_test.txt
```

## Rules

- Never skip or disable a failing test to make the suite pass
- Never use `--no-verify` or equivalent flags to bypass checks
- If a fix requires changing shared code, ensure it doesn't break other features
- Report the final count: total tests, passed, failed