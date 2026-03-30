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

```
openclient-llm/
├── App/                    # App entry point, app-level configuration
├── Features/               # Feature modules (Chat, Settings, Models...)
│   └── <Feature>/
│       ├── Views/          # SwiftUI views
│       ├── ViewModels/     # @Observable view models (Event/State pattern)
│       ├── UseCases/       # Business logic per use case
│       ├── Repositories/   # Data access abstraction
│       └── Models/         # Domain models for this feature
├── Core/
│   ├── Networking/         # API client, request/response models
│   ├── Managers/           # Transversal services (auth, settings, connectivity)
│   ├── Extensions/         # Swift/SwiftUI extensions
│   └── Utils/              # Shared utilities
├── Resources/              # Assets, Localizable strings
└── Platform/               # Platform-specific code (#if os(...))
    ├── iOS/
    ├── iPadOS/
    └── macOS/
```

> **Note**: This is the target structure. The project is in early MVP phase — create directories and groups as features are implemented.

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
- Localization-ready: use `String(localized:)` for user-facing strings

## Build and Test

- Build with Xcode 16+
- Run tests: `⌘U` in Xcode or `xcodebuild test`
- No external package manager — use Swift Package Manager (SPM) via Xcode
- **SwiftLint** integrated via SPM — all code must pass linting without warnings
- SwiftLint runs automatically as part of the build process
- Follow the rules defined in `.swiftlint.yml` at the project root
- When writing new code, respect SwiftLint conventions (line length, naming, force unwraps, etc.)
