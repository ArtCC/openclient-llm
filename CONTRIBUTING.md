# Contributing to OpenClient LLM

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

1. **Fork** the repository
2. **Clone** your fork locally
3. **Open** the project in Xcode 16+ or VS Code
4. **Create a branch** for your feature or fix

## Development Setup

### Requirements

- Xcode 16+ (for building and running)
- macOS 15+
- A LiteLLM server for testing (optional — see [LiteLLM docs](https://docs.litellm.ai/))

### Build

```bash
open openclient-llm.xcodeproj
# Or build from terminal:
xcodebuild -scheme openclient-llm -destination 'platform=iOS Simulator,name=iPhone 16'
```

## How to Contribute

### Reporting Bugs

- Use GitHub Issues
- Include: device/OS version, steps to reproduce, expected vs actual behavior
- Add screenshots or logs if applicable

### Suggesting Features

- Open a GitHub Issue with the `enhancement` label
- Describe the use case and why it would be useful

### Submitting Code

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Follow the project's code style (see below)
3. Write or update tests if applicable
4. Commit with clear, descriptive messages
5. Push to your fork and open a Pull Request

## Code Style

- **Swift 6+** with strict concurrency
- **SwiftUI** for all UI code
- Use `@Observable` macro (not `ObservableObject`)
- Prefer `async/await` over Combine
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- One public type per file, file named after the type
- Use `// MARK: -` for logical sections
- Include `#Preview` in every SwiftUI view file

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

## Code of Conduct

Be respectful and constructive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

## License

By contributing, you agree that your contributions will be licensed under the project's license.