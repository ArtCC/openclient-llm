---
description: "Build the project, check for SwiftLint errors and warnings, and fix them."
agent: "agent"
---

Build the project and fix any SwiftLint violations found.

## MCP Detection

Before building, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_build_sim`. Then follow the appropriate path below.

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

3. **Build** by calling `mcp_xcodebuildmcp_build_sim` (no extra arguments needed if defaults are set).
4. **Review output**: identify all SwiftLint warnings and errors from the build output.
5. **Report violations**: list every violation with file, line number, rule name, and description.
6. **If any violation is found**:
   - Read the affected file to understand context.
   - Fix the violation following `.swiftlint.yml` rules.
   - Call `mcp_xcodebuildmcp_build_sim` again to confirm the fix.
   - Repeat until zero violations remain.
7. **Report final result**: confirm clean build with no violations.

---

## Path B — XcodeBuildMCP not available (fallback)

1. **Build the project** using the shell command below.
2. **Review output**: identify all SwiftLint warnings and errors.
3. **Report violations**: list every violation with file, line number, rule name, and description.
4. **If any violation is found**:
   - Read the affected file to understand context.
   - Fix the violation following `.swiftlint.yml` rules.
   - Re-run the command to confirm the fix.
   - Repeat until zero violations remain.
5. **Report final result**: confirm clean build with no violations.

```bash
xcodebuild build \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -quiet 2>&1 | grep -E "error:|warning:" | grep -v "note:"
```

---

## Rules

- Never disable a SwiftLint rule (inline or in `.swiftlint.yml`) to suppress a violation
- Never use `// swiftlint:disable` comments to silence warnings
- Fix the root cause: refactor code to comply with the rule (extract methods, split files, rename variables, etc.)
- If a fix requires changing shared code, ensure it doesn't break other features
- Do not modify `.swiftlint.yml` unless explicitly asked by the user
- After fixing violations, run the full test suite to ensure nothing is broken
