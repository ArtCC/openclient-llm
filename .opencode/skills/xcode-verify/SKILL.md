---
name: xcode-verify
description: Use when building, linting, or verifying the openclient-llm Xcode project after Swift changes or when SwiftLint warnings/errors must be fixed.
---

# Xcode Verification

Use this skill to verify Swift changes in `openclient-llm`.

## Process

1. Before the first XcodeBuildMCP build or test call, use `session_show_defaults`.
2. Before building, create `Secrets.xcconfig` from the template in `AGENTS.md` if it is missing; never overwrite it.
3. Prefer XcodeBuildMCP. Use `build_sim` for compilation and `test_sim` for tests, with code signing disabled; add the documented test timeout arguments for test runs.
4. If an MCP request times out, use the complete `xcodebuild` fallback from `AGENTS.md`, including `-project`, code-signing overrides, and test timeouts.
5. Read every compiler error and SwiftLint warning in context before changing code.
6. Fix the root cause of every SwiftLint violation. Never disable rules, add `swiftlint:disable`, or modify `.swiftlint.yml` unless the user explicitly asks.
7. Run affected tests after each fix. Run the full iOS test suite after changes to shared code or before reporting completion.
8. Run `git diff --check` before completion.

## Completion Criteria

- The build has no compiler errors.
- SwiftLint reports no warnings or errors.
- Relevant tests pass; shared-code changes require the full suite.
- Report the test total, failures, and any verification that could not run.
