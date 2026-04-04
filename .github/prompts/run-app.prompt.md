---
description: "Build and launch the app on the iPhone 17 Pro Max simulator."
agent: "agent"
---

Build and run the app on the iPhone 17 Pro Max simulator so the user can interact with it.

## MCP Detection

Before building, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_build_run_sim`. Then follow the appropriate path below.

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

3. **Build and run** by calling `mcp_xcodebuildmcp_build_run_sim` (no extra arguments needed if defaults are set).
   - This boots the simulator automatically if needed and launches the app.

4. **Report**: confirm the app launched successfully. The user will now interact with it directly in the simulator.

---

## Path B — XcodeBuildMCP not available (fallback)

1. **Boot the simulator** (if not already running):

```bash
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true
open -a Simulator
```

2. **Build and install the app**:

```bash
xcodebuild build \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath /tmp/openclient-llm-build \
  2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED"
```

3. **Install and launch**:

```bash
# Get the booted simulator UDID
UDID=$(xcrun simctl list devices booted | grep "iPhone 17 Pro Max" | grep -E -o '[0-9A-F-]{36}' | head -1)

# Install the built app
xcrun simctl install "$UDID" \
  /tmp/openclient-llm-build/Build/Products/Debug-iphonesimulator/openclient-llm.app

# Launch the app
xcrun simctl launch "$UDID" com.artcc.openclient-llm
```

4. **Report**: confirm the app launched. The user will now interact with it directly in the simulator.

---

## Rules

- Do not modify source code unless a build error prevents the app from launching
- If the build fails due to SwiftLint violations, run the `build-lint` prompt first
- Do not alter simulator state beyond booting it (no erase, no reset)
- Do not capture or stream logs — the goal is to have the app running for the user to use