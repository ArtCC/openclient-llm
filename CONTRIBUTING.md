# Contributing to OpenClient LLM

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

1. **Fork** the repository
2. **Clone** your fork locally
3. **Open** the project in Xcode 26+ or VS Code
4. **Create a branch from `develop`** for your feature or fix

## Development Setup

### Requirements

- Xcode 26+ (for building and running)
- macOS 26+
- A LiteLLM server for testing (optional — see [LiteLLM docs](https://docs.litellm.ai/))

### Build

Create the gitignored configuration required by both app targets. Empty placeholders are sufficient to build; real
credentials are required to use the in-app Votice feedback screen:

```bash
cat > Secrets.xcconfig <<'EOF'
VOTICE_API_KEY =
VOTICE_API_SECRET =
VOTICE_APP_ID =
EOF
```

```bash
open openclient-llm.xcodeproj
# Or build from terminal:
xcodebuild build -project openclient-llm.xcodeproj -scheme openclient-llm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

If you use VS Code with the **XcodeBuildMCP** extension, the `build-lint`, `run-app`, and `run-tests` agent prompts handle build, launch, and testing automatically — with or without MCP installed.

## How to Contribute

### Reporting Bugs

- Use GitHub Issues
- Include: device/OS version, steps to reproduce, expected vs actual behavior
- Add screenshots or logs if applicable

### Suggesting Features

- Open a GitHub Issue with the `enhancement` label
- Describe the use case and why it would be useful

### Submitting Code

1. Create a feature branch from `develop`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Follow the project's code style (see below)
3. Write or update tests if applicable
4. Commit with clear, descriptive messages
5. Push to your fork and open a Pull Request targeting `develop`

## Code Style

- **Swift 6+** with strict concurrency
- **SwiftUI** for all UI code
- Use `@Observable` macro (not `ObservableObject`)
- Prefer `async/await` over Combine
- The iOS and macOS app targets default to `MainActor`; test and extension targets do not
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- One public type per file, file named after the type
- Use `// MARK: -` for logical sections
- Include `#Preview` in every SwiftUI view file
- SwiftLint warning/error limits are 120/150 lines for line length, 50/80 for function bodies, 300/400 for type
  bodies, and 500/650 for files; force unwraps and force casts are errors

## Commit Messages

Use clear, imperative-style commit messages:

```
Add chat streaming support
Fix model list not refreshing on reconnect
Update settings view for macOS layout
```

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Provide a clear description of what changed and why
- Reference related issues (e.g., `Closes #12`)
- Ensure the project builds without warnings
- Run the smallest relevant unit-test set. The repository currently has no real-server integration-test suite
- Do not commit `Secrets.xcconfig`

## Code of Conduct

Be respectful and constructive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

## License

By contributing, you agree that your contributions will be licensed under the project's license.
