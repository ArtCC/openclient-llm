# OpenClient LLM — Project Guidelines

## Overview

OpenClient LLM is a native Apple client for LiteLLM, a self-hosted LLM proxy server. The app allows users to interact with any LLM provider (Ollama, OpenAI, Anthropic, etc.) through a single unified LiteLLM endpoint.

- **Language**: Swift 6+
- **UI Framework**: SwiftUI
- **Platforms**: iOS, iPadOS, macOS (shared codebase, platform-specific UI)
- **Minimum deployment**: iOS 18, macOS 15
- **Architecture**: MVVM + UseCase + Repository + Manager with async/await concurrency
- **Backend**: LiteLLM self-hosted server (OpenAI-compatible API)

## Project Structure

The project has **3 Xcode targets** with File System Synchronized Groups:

```
openclient-llm/                # iOS target (also hosts all shared code)
├── App/                       # iOS app entry point
├── Shared/                    # Shared code used by both iOS and macOS targets
│   ├── Features/              # Feature modules (Chat, Settings, Models...)
│   │   └── <Feature>/
│   │       ├── Views/          # SwiftUI views (use #if os() when needed)
│   │       ├── ViewModels/     # @Observable view models (Event/State pattern)
│   │       ├── UseCases/       # Business logic per use case
│   │       ├── Repositories/   # Data access abstraction
│   │       └── Models/         # Domain models for this feature
│   └── Core/
│       ├── Networking/         # API client, request/response models
│       ├── Managers/           # Transversal services (auth, settings, connectivity)
│       ├── Extensions/         # Swift/SwiftUI extensions
│       └── Utils/              # Shared utilities
├── Views/                     # iOS-only views (strictly iOS-specific UI)
└── Resources/                 # iOS assets, Localizable strings

openclient-llm-macOS/          # macOS target (macOS-specific code only)
├── App/                       # macOS app entry point
├── Views/                     # macOS-only views (sidebar, toolbar, menu bar)
└── Resources/                 # macOS assets

openclient-llm-test/           # Unit tests target (linked to iOS target)
└── <Feature>Tests/            # Test files organized by feature
```

### Target Rules

- **`openclient-llm/Shared/`**: All business logic, models, networking, ViewModels, UseCases, Repositories, Managers. This code is shared — the macOS target references it.
- **`openclient-llm/`** (outside Shared): Only iOS/iPadOS-specific views, app entry point, and iOS resources.
- **`openclient-llm-macOS/`**: Only macOS-specific views, app entry point, and macOS resources. Never duplicate shared logic here.
- **`openclient-llm-test/`**: Unit tests for shared logic (ViewModels, UseCases, Repositories).

> **Note**: The project is in early MVP phase — create directories as features are implemented.

## Code Style

- Use Swift strict concurrency (`Sendable`, `@MainActor` where needed)
- Prefer `async/await` over Combine for async operations
- Use `@Observable` macro (Observation framework) — never use `ObservableObject` or `@Published`
- Mark view models with `@Observable @MainActor` and use `@State` in views
- Use Swift's native error handling (`throw`/`catch`) — no Result types unless needed for Combine
- Follow Swift API Design Guidelines for naming
- Use `guard` early returns for preconditions
- Prefer value types (`struct`, `enum`) over reference types unless shared mutable state is needed

## Architecture

### Layer Overview

```
View → ViewModel → UseCase → Repository → APIClient / LocalStorage
                      ↑
                   Manager (transversal services)
```

- **View**: SwiftUI views that observe ViewModels via `@State`. No business logic.
- **ViewModel**: `@Observable @MainActor` classes with Event/State pattern. Coordinates UseCases.
- **UseCase**: Encapsulates a single business operation (e.g., `SendMessageUseCase`, `FetchModelsUseCase`). Calls Repositories and Managers.
- **Repository**: Abstracts data access (network, cache, local storage). Protocols for testability.
- **Manager**: Transversal services used across features (auth, settings, connectivity). Called from UseCases.
- **APIClient**: Single networking layer using `URLSession` + `async/await` to communicate with LiteLLM.

### ViewModel Template (Event/State Pattern)

All ViewModels follow this standard pattern:

```swift
import Foundation

@Observable
@MainActor
final class FeatureViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {}

    private(set) var state: State

    // MARK: - Init

    init(state: State = .loading) {
        self.state = state
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            state = .loaded(.init())
        }
    }
}

// MARK: - Private

private extension FeatureViewModel {}
```

### View Template

```swift
import SwiftUI

struct FeatureView: View {
    // MARK: - Properties

    @State private var viewModel = FeatureViewModel()

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                VStack {
                    Image(systemName: "globe")
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension FeatureView {}

#Preview {
    FeatureView()
}
```

### General Principles

- **Dependency injection**: Pass dependencies through initializers or SwiftUI environment
- **Navigation**: Use `NavigationStack` with typed navigation paths
- **Platform adaptation**: Use `#if os(iOS)` / `#if os(macOS)` for platform-specific code; keep shared logic in Core/
- **Protocols for abstraction**: Repositories and Managers should have protocol definitions for testability

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
- **Supported languages**: Spanish (es), Italian (it), German (de), Portuguese - Portugal (pt-PT)
- **String catalog**: `Localizable.xcstrings` — the single source of truth for all translations
- **API**: Always use `String(localized:)` for user-facing strings in Swift code:
  ```swift
  // Simple string
  Text(String(localized: "Send"))
  
  // String with interpolation
  Text(String(localized: "\(count) messages"))
  
  // String with comment for translators
  String(localized: "Delete", comment: "Button to delete a conversation")
  ```
- **Mandatory rule**: Every time a user-facing string is added or modified in code, all translations in `Localizable.xcstrings` must be updated simultaneously for every supported language
- **Translation quality**: Translations must be grammatically and orthographically correct in each language — no machine-translated placeholders or approximations
- **Language-specific notes**:
  - **Spanish (es)**: Use neutral/international Spanish, informal "tú" form
  - **Italian (it)**: Use informal "tu" form
  - **German (de)**: Use informal "du" form, capitalize nouns
  - **Portuguese (pt-PT)**: Use European Portuguese (Portugal), not Brazilian Portuguese, informal "tu" form
- **Review checklist** when adding/editing strings:
  1. String uses `String(localized:)` — never raw string literals for user-facing text
  2. English (en) key is clear and descriptive
  3. All 5 languages have correct translations in `Localizable.xcstrings`
  4. Pluralization handled with the string catalog's plural rules when needed
  5. Context comments added for ambiguous strings
- **Do not** hardcode user-facing text directly in views without localization
- **Do not** leave any language with missing or empty translations

## Build and Test

- Build with Xcode 16+
- Run tests: `⌘U` in Xcode or `xcodebuild test`
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
