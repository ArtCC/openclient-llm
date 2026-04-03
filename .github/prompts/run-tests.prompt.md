---
description: "Run all unit tests, report results, and fix any failures found."
agent: "agent"
---

Run the full unit test suite for the project and report results.

## MCP Detection

Before running tests, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_test_sim`. Then follow the appropriate path below.

---

## Path A — XcodeBuildMCP available (preferred)

1. **Resolve the absolute project path** by running:
   ```bash
   find "$(pwd)" -maxdepth 2 -name "openclient-llm.xcodeproj" | head -1
   ```
   Use the resulting absolute path for all subsequent MCP calls.

2. **Verify session defaults** by calling `mcp_xcodebuildmcp_session_show_defaults`.
   - Defaults are pre-configured in `.xcodebuildmcp/config.yaml` and loaded automatically at server startup:
     - scheme: `openclient-llm`
     - simulator: `iPhone 17 Pro Max`
   - If `projectPath` is missing or resolves incorrectly (relative paths may fail), set it with `mcp_xcodebuildmcp_session_set_defaults` using the absolute path resolved in step 1.
   - Only override other values if they are missing or wrong.

3. **Run all tests** by calling `mcp_xcodebuildmcp_test_sim` (no extra arguments needed if defaults are set).
4. **Report results**: list every test case with pass/fail status.
5. **If any test fails**:
   - Investigate the failure by reading the relevant test and source files.
   - Fix the issue in the source code (not in the test, unless the test itself is wrong).
   - Call `mcp_xcodebuildmcp_test_sim` again to confirm the fix.
   - Repeat until all tests pass.
6. **Report final count**: total tests, passed, failed.

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

---

## Rules

- Never skip or disable a failing test to make the suite pass
- Never use `--no-verify` or equivalent flags to bypass checks
- If a fix requires changing shared code, ensure it doesn't break other features
- Report the final count: total tests, passed, failed