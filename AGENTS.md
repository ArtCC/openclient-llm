# AGENTS.md

This file is the project-wide operating guide. It resolves facts that would otherwise require reading multiple configuration files; focused implementation rules live in `specs/`.

## Instruction Order

1. Read this file before changing the project.
2. Read every specification relevant to the requested work before editing.
3. If instructions conflict, follow repository-specific instructions over general guidance. When two project instructions conflict, stop and ask for clarification.
4. Keep this file limited to durable, project-wide facts. Put focused or evolving implementation rules in `specs/`.

## Specifications

Each specification must use the `.instructions.md` suffix and start with YAML front matter containing a `description`. Add an `applyTo` pattern when the scope can be expressed by file path. When adding or removing a specification, update this table in the same change.

| File | Read when |
|---|---|
| `agent-tool-calling.instructions.md` | Implementing tool calling, tool UI, or the agent loop. |
| `architecture.instructions.md` | Creating Swift files, features, or changing layer boundaries. |
| `changelog.instructions.md` | Updating `CHANGELOG.md`. |
| `chat-visual-style.instructions.md` | Designing chat-specific SwiftUI. |
| `code-style.instructions.md` | Writing or reviewing Swift style. |
| `concurrency.instructions.md` | Working with async code, isolation, or `Sendable`. |
| `conversation-backup-format.instructions.md` | Exporting, importing, restoring, validating, or versioning conversation backups. |
| `design-ui.instructions.md` | Designing general SwiftUI UI, accessibility, haptics, or animation. |
| `litellm-api.instructions.md` | Changing LiteLLM/OpenAI-compatible API integration. |
| `readme.instructions.md` | Updating `README.md`. |
| `roadmap.instructions.md` | Planning or prioritizing future work. |
| `roadmap-completed.instructions.md` | Reviewing completed roadmap work. |
| `security.instructions.md` | Handling sensitive data, user input, credentials, or security review. |
| `swiftui-multiplatform.instructions.md` | Building shared iOS, iPadOS, or macOS SwiftUI. |
| `testing.instructions.md` | Adding or changing tests and mocks. |
| `web-browsing.instructions.md` | Implementing web search or browsing features. |

## Platform & Services

- Target Swift 6+ with SwiftUI on iOS, iPadOS, and macOS. Minimum deployment is iOS 26 and macOS 26.
- The app connects to a self-hosted LiteLLM server through its OpenAI-compatible API. The base URL is user-configurable.
- Store credentials in `KeychainManager`; store non-sensitive settings in `SettingsManager`.

## Build & Run

```bash
# Build iOS scheme (default)
xcodebuild build -project openclient-llm.xcodeproj -scheme openclient-llm -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Build macOS scheme
xcodebuild build -project openclient-llm.xcodeproj -scheme openclient-llm-macOS -destination 'platform=macOS'
```

- Use `.xcodeproj` (not `.xcworkspace`). The three SPM packages are SwiftLintPlugins, VoticeSDK, and ConfettiSwiftUI.
- SwiftLint runs on the iOS and macOS app builds. `.swiftlint.yml` sets line-length warning/error limits to
  120/150, function-body limits to 50/80, type-body limits to 300/400, and file-length limits to 500/650;
  force unwraps and force casts are errors.
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

The iOS and macOS app targets set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; shared code therefore inherits
main-actor isolation when compiled into either app. The test, Share Extension, and WidgetsExtension targets do not set it.

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

Tests live in `openclient-llm-test/`, linked to the iOS target. They are unit and in-process integration tests; there
are no UI tests or current tests that call a real LiteLLM/Ollama server.

### Test conventions

- Naming: `test_<method>_<scenario>_<expectedResult>()` (e.g. `test_fetchModels_serverUnavailable_returnsEmpty()`).
- Import: `@testable import openclient_llm`.
- Structure: Given-When-Then with `// Given` / `// When` / `// Then` comments.
- Mocks live in `openclient-llm-test/Mocks/`, named `MockXxx`, protocol-based.
- Test classes mirror feature folders: `Features/Chat/` → `Features/Chat/ChatViewModelTests.swift`.
- Add isolated tests for UseCases, Repositories, and ViewModels. Use protocols and mocks for dependencies.

## Project Structure And Targets

| Target | Purpose |
|---|---|
| `openclient-llm` | iOS app + all shared code |
| `openclient-llm-macOS` | macOS app (macOS-only UI; references `Shared/` from iOS target) |
| `openclient-llm-test` | Unit tests (linked to iOS target) |
| `ShareExtension` | iOS Share Extension (does NOT link Shared code; uses App Group) |
| `WidgetsExtension` | WidgetKit extension sourced from `Widgets/`; uses the App Group and selected shared resource files |

- Shared business logic lives in `openclient-llm/Shared/` and is referenced by both app targets.
- Platform-specific UI goes in each target's own folder. Use `#if os(iOS)` / `#if os(macOS)` only when the difference is small.
- `ShareExtension` does not link `Shared/`; it has extension-local payload/store types compatible with the main app.
- `WidgetsExtension` does not link the shared feature layer. `AppGroupStore` and `WidgetConversation` are compiled into
  both apps and the extension; `WidgetControlStore` is compiled into the iOS app and extension.
- App Group: `group.com.artcc.openclient-llm`

## Architecture: Event/State ViewModels

ViewModels use `@Observable`, explicit `@MainActor`, event-driven `send(_:)` input, and screen-specific state. Most use
the following Event/State shape; `HomeViewModel` instead exposes several focused observable properties:

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
- ViewModels primarily coordinate UseCases, but some also inject Managers directly for settings, memory, cloud sync,
  user profile, and app-wide routing state. Preserve the local pattern instead of adding pass-through UseCases.
- ViewModel `send(_:)` is the public input point; asynchronous work and state mutation stay inside the ViewModel.
- Typical data flow is View → ViewModel → UseCase → Repository → APIClient/LocalStorage. Managers are transversal
  services coordinated by UseCases, ViewModels, repositories, and app entry points where the implementation requires it.

## File conventions

- Every `.swift` file starts with the boilerplate copyright header (see any existing file).
- One public type per file, named after the type.
- `// MARK: - Properties` / `// MARK: - Init` / `// MARK: - <public section>` / `// MARK: - Private` at file bottom.
- Every SwiftUI view file must include `#Preview`.
- Never initialize optional stored properties with `= nil` (optionals default to nil).
- Use `String(localized:)` for ALL user-facing strings. Never manually edit `Localizable.xcstrings` — Xcode syncs it from `String(localized:)` usage.
- Write localized source strings in English only; translations are maintained manually by the project author.
- SwiftLint configuration: warnings/errors are 120/150 lines for line length, 50/80 for function bodies, 300/400 for
  type bodies, and 500/650 for files. `force_unwrapping` and `force_cast` are errors.
- External SPM packages are SwiftLintPlugins, VoticeSDK, and ConfettiSwiftUI; do not add others without a concrete need.

## Git workflow

- Branch from `develop`, open PRs targeting `develop`.
- Commit messages: imperative style ("Add chat streaming support"), reference related issues with `Closes #N`.
- Do NOT commit `Secrets.xcconfig` (gitignored; contains Votice API keys).
- Values from `Secrets.xcconfig` are compiled into the client app and are recoverable from a distributed bundle. Treat them
  as client configuration, not as confidential server-side secrets; never place a privileged credential there.
- Release workflows derive tag and artifact labels from the first numeric `CHANGELOG.md` header. The deployment process
  increments the published build number automatically, so the checked-in `CURRENT_PROJECT_VERSION` does not need to match
  the changelog build suffix. Tags use the full changelog version prefixed with `v`.

## Change Completion

- After completing implementation work, **always ask the user** before compiling, checking SwiftLint, or running tests. Never do these automatically.
- When the user wants to verify: run the smallest relevant test set after a focused change; run the full iOS suite after shared-code changes.
- Build both iOS and macOS after changing shared SwiftUI or shared business logic.
- Run `git diff --check` before reporting completion.
- Do not include generated files, `Secrets.xcconfig`, or unrelated working-tree changes in a commit.
