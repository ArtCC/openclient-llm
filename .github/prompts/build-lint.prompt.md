---
description: "Build the project, check for SwiftLint errors and warnings, and fix them."
agent: "agent"
---

Build the project and fix any SwiftLint violations found.

Before either path, ensure the required local build configuration exists. Do not overwrite an existing file:

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

Before building, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_build_sim`. Then follow the appropriate path below.

---

## Path A — XcodeBuildMCP available (preferred)

1. **Verify session defaults** by calling `mcp_xcodebuildmcp_session_show_defaults` before the first build.
   - Defaults are pre-configured in `.xcodebuildmcp/config.yaml` and loaded automatically at server startup:
     - scheme: `openclient-llm`
     - simulator: `iPhone 17 Pro Max`
   - If `projectPath` is missing or wrong, use project discovery and set it with `mcp_xcodebuildmcp_session_set_defaults`.
   - Only override other values if they are missing or wrong.

2. **Build** by calling `mcp_xcodebuildmcp_build_sim` with `CODE_SIGN_IDENTITY=""` and `CODE_SIGNING_REQUIRED=NO` as extra build arguments.
3. **Review output**: identify all SwiftLint warnings and errors from the build output.
4. **Report violations**: list every violation with file, line number, rule name, and description.
5. **If any violation is found**:
   - Read the affected file to understand context.
   - Fix the violation following `.swiftlint.yml` rules.
   - Call `mcp_xcodebuildmcp_build_sim` again to confirm the fix.
   - Repeat until zero violations remain.
6. **Report final result**: confirm clean build with no violations.

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
set -o pipefail
xcodebuild build \
  -project openclient-llm.xcodeproj \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee /tmp/openclient-llm-build.log
```

---

## Rules

- Never disable a SwiftLint rule (inline or in `.swiftlint.yml`) to suppress a violation
- Never use `// swiftlint:disable` comments to silence warnings
- Fix the root cause: refactor code to comply with the rule (extract methods, split files, rename variables, etc.)
- If a fix requires changing shared code, ensure it doesn't break other features
- Do not modify `.swiftlint.yml` unless explicitly asked by the user
- After fixing violations, run the full test suite to ensure nothing is broken
