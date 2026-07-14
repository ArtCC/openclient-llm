---
description: "Build and launch the app on the iPhone 17 Pro Max simulator."
agent: "agent"
---

Build and run the app on the iPhone 17 Pro Max simulator so the user can interact with it.

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

Before building, check whether the **XcodeBuildMCP** MCP server is available by searching for its tools using `tool_search_tool_regex` with the pattern `mcp_xcodebuildmcp_build_run_sim`. Then follow the appropriate path below.

---

## Path A — XcodeBuildMCP available (preferred)

1. **Verify session defaults** by calling `mcp_xcodebuildmcp_session_show_defaults` before the first build.
   - Defaults are pre-configured in `.xcodebuildmcp/config.yaml` and loaded automatically at server startup:
     - scheme: `openclient-llm`
     - simulator: `iPhone 17 Pro Max`
   - If `projectPath` is missing or wrong, use project discovery and set it with `mcp_xcodebuildmcp_session_set_defaults`.
   - Only override other values if they are missing or wrong.

2. **Build and run** by calling `mcp_xcodebuildmcp_build_run_sim` with `CODE_SIGN_IDENTITY=""` and `CODE_SIGNING_REQUIRED=NO` as extra build arguments.
   - This boots the simulator automatically if needed and launches the app.

3. **Report**: confirm the app launched successfully. The user will now interact with it directly in the simulator.

---

## Path B — XcodeBuildMCP not available (fallback)

1. **Boot the simulator** (if not already running):

```bash
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true
open -a Simulator
```

2. **Build and install the app**:

```bash
set -o pipefail
xcodebuild build \
  -project openclient-llm.xcodeproj \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath /tmp/openclient-llm-build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tee /tmp/openclient-llm-build.log
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
