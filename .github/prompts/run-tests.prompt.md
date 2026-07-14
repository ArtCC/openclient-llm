---
description: "Run all unit tests, report results, and fix any failures found."
agent: "agent"
---

Run the full unit test suite for the project and report results.

Before either path, create the required local build configuration if it does not exist. Never overwrite an existing file:

```bash
if [ ! -f Secrets.xcconfig ]; then
  cat > Secrets.xcconfig << 'EOF'
VOTICE_API_KEY =
VOTICE_API_SECRET =
VOTICE_APP_ID =
EOF
fi
```

## MCP Detection

Before running tests, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_test_sim`. Then follow the appropriate path below.

---

## Path A — XcodeBuildMCP available (preferred)

1. **Verify session defaults** by calling `mcp_xcodebuildmcp_session_show_defaults` before the first test call.
   - Defaults are pre-configured in `.xcodebuildmcp/config.yaml` and loaded automatically at server startup:
     - scheme: `openclient-llm`
     - simulator: `iPhone 17 Pro Max`
   - If `projectPath` is missing or wrong, use project discovery and set it with `mcp_xcodebuildmcp_session_set_defaults`.
   - Only override other values if they are missing or wrong.

2. **Run all tests** by calling `mcp_xcodebuildmcp_test_sim` with `-test-timeouts-enabled YES`, `-maximum-test-execution-time-allowance 120`, `CODE_SIGN_IDENTITY=""`, and `CODE_SIGNING_REQUIRED=NO` as extra arguments.
3. **Report results**: list every test case with pass/fail status.
4. **If any test fails**:
   - Investigate the failure by reading the relevant test and source files.
   - Fix the issue in the source code (not in the test, unless the test itself is wrong).
   - Call `mcp_xcodebuildmcp_test_sim` again to confirm the fix.
   - Repeat until all tests pass.
5. **Report final count**: total tests, passed, failed.

---

## Path B — XcodeBuildMCP not available (fallback)

1. **Run all tests** using the shell command below.
2. **Report results**: list every test case with pass/fail status.
3. **If any test fails**:
   - Investigate the failure by reading the relevant test and source files.
   - Fix the issue in the source code (not in the test, unless the test itself is wrong).
   - Re-run the command to confirm the fix.
   - Repeat until all tests pass.
4. **Report final count**: total tests, passed, failed.

```bash
set -o pipefail
xcodebuild test \
  -project openclient-llm.xcodeproj \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 120 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee /tmp/xcodebuild_test.txt
```

This single command:
- Runs the full test suite without `-quiet` (so all output is available)
- Preserves and displays the complete output while returning the real `xcodebuild` status
- Saves the full output to `/tmp/xcodebuild_test.txt` for inspection if needed

To read failed test details after the run:
```bash
grep -A 5 "failed" /tmp/xcodebuild_test.txt
```

---

## Rules

- Never skip or disable a failing test to make the suite pass
- Never use `--no-verify` or equivalent flags to bypass checks
- If a fix requires changing shared code, ensure it doesn't break other features
- Report the final count: total tests, passed, failed
