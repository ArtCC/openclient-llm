---
description: "Build the project, check for SwiftLint errors and warnings, and fix them."
agent: "agent"
---

Build the project and fix any SwiftLint violations found.

## Steps

1. **Build the project** using `xcodebuild build` with the `openclient-llm` scheme targeting an iOS Simulator
2. **Review output**: identify all SwiftLint warnings and errors from the build output
3. **Report violations**: list every SwiftLint violation with file, line number, rule name, and description
4. **If any violation is found**:
   - Read the affected file to understand the context
   - Fix the violation in the source code following SwiftLint rules defined in `.swiftlint.yml`
   - Re-run the build to confirm the fix
   - Repeat until zero SwiftLint violations remain
5. **Report final result**: confirm clean build with no violations

## Command

```bash
xcodebuild build \
  -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet 2>&1 | grep -E "error:|warning:" | grep -v "note:"
```

## Rules

- Never disable a SwiftLint rule (inline or in `.swiftlint.yml`) to suppress a violation
- Never use `// swiftlint:disable` comments to silence warnings
- Fix the root cause: refactor code to comply with the rule (extract methods, split files, rename variables, etc.)
- If a fix requires changing shared code, ensure it doesn't break other features
- Do not modify `.swiftlint.yml` unless explicitly asked by the user
- After fixing violations, run the full test suite to ensure nothing is broken
