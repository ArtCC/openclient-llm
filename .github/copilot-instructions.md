# OpenClient LLM — Project Guidelines

## Important

Any modification to project instructions, guidelines, or definition files (`.github/copilot-instructions.md`, `.github/instructions/*.md`, `.github/prompts/*.md`, `.swiftlint.yml`) must be **explicitly confirmed by the user before applying changes**. Always explain the proposed change first and wait for approval.

## Overview

OpenClient LLM is a native Apple client for LiteLLM, a self-hosted LLM proxy server. The app allows users to interact with any LLM provider (Ollama, OpenAI, Anthropic, etc.) through a single unified LiteLLM endpoint.

- **Language**: Swift 6+
- **UI Framework**: SwiftUI
- **Platforms**: iOS, iPadOS, macOS (shared codebase, platform-specific UI)
- **Minimum deployment**: iOS 26, macOS 26
- **Architecture**: MVVM + UseCase + Repository + Manager with async/await concurrency
- **Backend**: LiteLLM self-hosted server (OpenAI-compatible API)

> For detailed architecture patterns, project structure, code style conventions, and templates, see `.github/instructions/architecture.instructions.md`.

## LiteLLM API

The app communicates with a LiteLLM proxy server via its OpenAI-compatible REST API:

- Base URL is user-configurable (self-hosted)
- Authentication via API key (optional, depends on LiteLLM config)
- Key endpoints:
  - `POST /chat/completions` — Send chat messages, supports streaming via SSE
  - `GET /models` — List available models
  - `GET /health` — Server health check
- All requests and responses follow the OpenAI API format
- Support streaming responses with `stream: true` parameter

## Conventions

- Files are organized by feature, not by type
- One public type per file, file named after the type
- Use `// MARK: -` to separate logical sections in larger files
- Preview providers (`#Preview`) in every SwiftUI view file
- Use SF Symbols for icons
- Support Dark Mode by default
- Use semantic colors from asset catalog, not hardcoded
- All user-facing strings must be localized — see Localization section below

## Localization

- **Base language**: English (en)
- **Supported languages**: Defined in `knownRegions` inside `openclient-llm.xcodeproj/project.pbxproj`
- **String catalog**: `Localizable.xcstrings` — the single source of truth for all translations
- **Never manually edit `Localizable.xcstrings`**: Xcode automatically syncs strings from `String(localized:)` usage in code upon compilation. Just use the correct API in Swift code and the strings will appear in the catalog after building.
- **API**: Always use `String(localized:)` for user-facing strings in Swift code:
  ```swift
  // Simple string
  Text(String(localized: "Send"))
  
  // String with interpolation
  Text(String(localized: "\(count) messages"))
  
  // String with comment for translators
  String(localized: "Delete", comment: "Button to delete a conversation")
  ```
- **Translations**: Only write strings in English in Swift code. Do **not** add translations to other languages — the author handles translations manually
- **Review checklist** when adding/editing strings:
  1. String uses `String(localized:)` — never raw string literals for user-facing text
  2. English (en) key is clear and descriptive
  3. Pluralization handled with the string catalog's plural rules when needed
  4. Context comments added for ambiguous strings
  5. **Do not** manually edit `Localizable.xcstrings` — let Xcode sync it automatically
- **Do not** hardcode user-facing text directly in views without localization

## Build and Test

- Build with Xcode 26+
- **XcodeBuildMCP** is configured for this project via `.xcodebuildmcp/config.yaml` — use it when available (VS Code agent prompts handle detection automatically)
- Run tests: `⌘U` in Xcode, `xcodebuild test` in terminal, or via the `run-tests` agent prompt
- Build and lint: use the `build-lint` agent prompt (supports XcodeBuildMCP or `xcodebuild` fallback)
- Run app on simulator: use the `run-app` agent prompt (supports XcodeBuildMCP or `xcodebuild` fallback)
- **No external dependencies** except SwiftLint — networking, persistence, and all logic is custom
- Use Swift Package Manager (SPM) via Xcode only for dev tools (SwiftLint)
- Sensitive data (API keys) stored in **Keychain** via `KeychainManager`
- Non-sensitive settings stored in **UserDefaults** via `SettingsManager`
- **SwiftLint** integrated via SPM — all code must pass linting without warnings
- SwiftLint runs automatically as part of the build process
- Follow the rules defined in `.swiftlint.yml` at the project root
- When writing new code, respect SwiftLint conventions (line length, naming, force unwraps, etc.)
- **Unit tests**: All UseCases, Repositories, and ViewModels must have tests in `openclient-llm-test/`
- **Integration tests**: API tests guarded by environment variable, skipped by default
- **No UI tests** — only unit and integration tests
- Use protocols + mocks for dependency isolation in tests