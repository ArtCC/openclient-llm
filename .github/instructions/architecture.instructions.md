---
description: "Use when implementing features, creating new files, defining layer boundaries, following MVVM+UseCase+Repository patterns, writing Swift code, applying code style conventions, or understanding project structure."
applyTo: "**/*.swift"
---

# OpenClient LLM — Architecture & Best Practices

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

> **Note**: Create directories as features are implemented.

## Code Style

### File Header

Every Swift file must include this header at the top:

```swift
//
//  FileName.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on DD/MM/YYYY.
//  Copyright © YYYY Arturo Carretero Calvo. All rights reserved.
//

import Foundation
```

- Replace `FileName.swift` with the actual file name
- Replace `DD/MM/YYYY` with the creation date
- Replace `YYYY` with the creation year
- `import` goes after the header, separated by one blank line

### MARK Conventions

Use `// MARK: -` to separate logical sections in every file. Standard order:

**For classes/structs:**

```swift
// MARK: - Properties
// MARK: - Init
// MARK: - Deinit      (only if needed)
// MARK: - Public       (or named section like "Input functions")
// MARK: - Private      (as extension at bottom of file)
```

**For Views:**

```swift
// MARK: - Properties
// MARK: - View
// MARK: - Private      (as extension at bottom of file)
```

### Extensions for Code Organization

Use `private extension` at the bottom of the file to group all private methods. Use named extensions for protocol conformances and logical groupings:

```swift
// Full class example:
@Observable
@MainActor
final class FeatureViewModel {
    // MARK: - Properties

    private(set) var state: State

    // MARK: - Init

    init(state: State = .loading) {
        self.state = state
    }

    // MARK: - Input functions

    func send(_ event: Event) { ... }
}

// MARK: - Private

private extension FeatureViewModel {
    func loadData() { ... }
    func handleError(_ error: Error) { ... }
}
```

For types with protocol conformances, use separate extensions:

```swift
// MARK: - CustomStringConvertible

extension ChatMessage: CustomStringConvertible {
    var description: String { ... }
}
```

### General Rules

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