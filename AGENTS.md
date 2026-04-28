# AGENTS.md

This file supplements `.github/copilot-instructions.md` and `.github/instructions/` with facts an agent would likely miss without reading multiple config files.

## Build & Run

```bash
# Build iOS scheme (default)
xcodebuild build -project openclient-llm.xcodeproj -scheme openclient-llm -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Build macOS scheme
xcodebuild build -project openclient-llm.xcodeproj -scheme openclient-llm-macOS -destination 'platform=macOS'
```

- Use `.xcodeproj` (not `.xcworkspace`). SwiftLint is the only SPM dependency and is integrated inside Xcode.
- CI skips code signing: append `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` to `xcodebuild` commands.
- VS Code + XcodeBuildMCP is supported (config at `.xcodebuildmcp/config.yaml`).
- **You must create a `Secrets.xcconfig` before building.** Copy the template from CI:

```bash
cat > Secrets.xcconfig << 'EOF'
VOTICE_API_KEY =
VOTICE_API_SECRET =
VOTICE_APP_ID =
EOF
```

## Concurrency (critical)

The project build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means **every type and method is `@MainActor` unless explicitly opted out**.

- `@MainActor` annotations on ViewModels are redundant but kept for documentation.
- All test classes **must** be `@MainActor` — otherwise they cannot access `@MainActor`-isolated types synchronously.
- Use `nonisolated` ONLY for genuinely background work (image processing, large JSON parsing).
- `@unchecked Sendable` requires a documented safety invariant comment — never use without justification.
  - Production wrappers: `// Safety: <API> is thread-safe per Apple documentation. All stored properties are immutable (\`let\`).`
  - Test mocks: `// Safety: Only used within serialized @MainActor test methods.`
- No `ObservableObject` / `@Published` — use `@Observable` macro everywhere.

## Test commands

```bash
# Run all tests (iOS scheme)
xcodebuild test -project openclient-llm.xcodeproj -scheme openclient-llm -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run a single test class
xcodebuild test -project openclient-llm.xcodeproj -scheme openclient-llm -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:openclient-llm-test/ChatViewModelTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Tests live in `openclient-llm-test/`, linked to the iOS target. No UI tests — unit and integration only. Integration tests that need a real server are gated by `ProcessInfo.processInfo.environment["LITELLM_TEST_URL"]` and skipped by default.

### Test conventions

- Naming: `test_<method>_<scenario>_<expectedResult>()` (e.g. `test_fetchModels_serverUnavailable_returnsEmpty()`).
- Import: `@testable import openclient_llm`.
- Structure: Given-When-Then with `// Given` / `// When` / `// Then` comments.
- Mocks live in `openclient-llm-test/Mocks/`, named `MockXxx`, protocol-based.
- Test classes mirror feature folders: `Features/Chat/` → `Features/Chat/ChatViewModelTests.swift`.

## Project structure & targets

| Target | Purpose |
|---|---|
| `openclient-llm` | iOS app + all shared code |
| `openclient-llm-macOS` | macOS app (macOS-only UI; references `Shared/` from iOS target) |
| `openclient-llm-test` | Unit tests (linked to iOS target) |
| `ShareExtension` | iOS Share Extension (does NOT link Shared code; uses App Group) |
| `Widgets` | WidgetKit extension (does NOT link Shared code; uses App Group) |

- Shared business logic lives in `openclient-llm/Shared/` and is referenced by both iOS and macOS targets.
- Platform-specific UI goes in each target's own folder. Use `#if os(iOS)` / `#if os(macOS)` only when the difference is small.
- App Group: `group.com.artcc.openclient-llm`

## Architecture: Event/State ViewModels

All ViewModels follow this exact pattern:

```swift
@Observable
@MainActor
final class FeatureViewModel {
    enum Event { case viewAppeared }
    enum State: Equatable { case loading; case loaded(LoadedState) }
    struct LoadedState: Equatable { /* screen data */ }

    private(set) var state: State
    init(state: State = .loading) { self.state = state }
    func send(_ event: Event) { /* switch on event */ }
}
```

- Views access ViewModels via `@State private var viewModel = FeatureViewModel()`.
- ViewModels call UseCases (never Managers directly — `LogManager` is the one exception, it's a static diagnostic utility).
- ViewModel `send(_:)` is the single input point. No scattered mutation from outside.
- Full architecture: View → ViewModel → UseCase → Repository → APIClient/LocalStorage, with Managers as transversal services.

## File conventions

- Every `.swift` file starts with the boilerplate copyright header (see any existing file).
- One public type per file, named after the type.
- `// MARK: - Properties` / `// MARK: - Init` / `// MARK: - <public section>` / `// MARK: - Private` at file bottom.
- Every SwiftUI view file must include `#Preview`.
- Never initialize optional stored properties with `= nil` (optionals default to nil).
- Use `String(localized:)` for ALL user-facing strings. Never manually edit `Localizable.xcstrings` — Xcode syncs it from `String(localized:)` usage.
- SwiftLint configuration: `.swiftlint.yml` enforces `force_unwrapping` and `force_cast` as errors, max line length 120, max function body 50 lines.
- No external dependencies beyond SwiftLint.

## Git workflow

- Branch from `develop`, open PRs targeting `develop`.
- Commit messages: imperative style ("Add chat streaming support"), reference related issues with `Closes #N`.
- Do NOT commit `Secrets.xcconfig` (gitignored; contains Votice API keys).
- Version is sourced from `CHANGELOG.md` (first `## [X.Y.Z]` header). Tags use `vX.Y.Z` format.
