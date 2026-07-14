---
description: "Use when implementing features, creating new files, defining layer boundaries, following MVVM+UseCase+Repository patterns, writing Swift code, applying code style conventions, or understanding project structure."
applyTo: "**/*.swift"
---

# OpenClient Architecture

## Current Project Layout

The Xcode project currently has **five native targets**, all backed by File System Synchronized Groups:

```text
openclient-llm/                 # iOS/iPadOS app target
├── App/                        # iOS app and scene delegates
├── Resources/                  # iOS plist, entitlements, test plan
└── Shared/                     # Compiled by both app targets
    ├── Core/
    │   ├── Extensions/
    │   ├── Managers/
    │   ├── Models/
    │   ├── Networking/
    │   ├── Utils/
    │   └── Views/
    ├── Features/               # Feature-owned Models/Repositories/UseCases/ViewModels/Views as needed
    └── Resources/              # Shared assets, localization, icon, and Poppins fonts

openclient-llm-macOS/           # macOS app target
├── App/
├── Resources/
└── Views/                      # macOS-only menu bar and command UI

openclient-llm-test/            # iOS-hosted XCTest unit test target
├── Core/
├── Features/
└── Mocks/

ShareExtension/                 # Standalone iOS Share Extension
└── App/Models/                 # Duplicates its small App Group transfer model/store intentionally

Widgets/                        # Standalone WidgetsExtension target
└── App/                        # WidgetKit widgets, controls, intents, and App Group models
```

The macOS target includes the synchronized `openclient-llm` group as well as its own group. Shared views therefore live in
`openclient-llm/Shared/Features/.../Views`, not in a separate iOS `Views/` directory. `ShareExtension` and
`WidgetsExtension` do not link the shared feature layer; they communicate through `group.com.artcc.openclient-llm` and
deep links. Through synchronized-group membership exceptions, `AppGroupStore.swift` and `WidgetConversation.swift` are
also compiled into both apps, while `WidgetControlStore.swift` is compiled into the iOS app and WidgetsExtension.

Feature folders are pragmatic rather than uniform. Create only the subfolders a feature needs. `Shortcuts`, for example,
currently contains intents directly, while larger features use several layer folders.

## Current Layering

The dominant flow is:

```text
View -> ViewModel -> UseCase -> Repository -> APIClient / local storage
                         \----> Manager
```

- Views own `@Observable` ViewModels with `@State`, render state, and send events.
- ViewModels are explicit `@MainActor` classes and generally expose a nested `Event`, `State`, and `LoadedState`.
- UseCases represent operations, but some are thin adapters over Managers or `APIClient` rather than Repository clients.
- Repositories handle network mapping, attachments, and conversation persistence where that abstraction is useful.
- Managers provide settings, keychain, cloud, audio, App Group, notification, and system-service integration.
- `APIClient` is the OpenAI-compatible networking and streaming boundary.

Current code does **not** enforce a pure ViewModel-to-UseCase boundary. Several ViewModels inject Managers directly,
including settings, memory, profile, cloud sync, shortcuts, sharing, and URL-scheme services. Treat that as current
implementation, not as evidence that every new dependency should bypass a UseCase.

## Preferred Rules For New Work

- Preserve the existing View -> ViewModel -> UseCase -> Repository/Manager flow when it adds a meaningful business or
  test seam. Do not add a pass-through UseCase solely to satisfy a diagram.
- Views must not perform persistence, networking, or business decisions.
- Prefer protocol-backed dependencies and initializer injection for testable boundaries.
- A ViewModel may use a Manager directly when it represents UI-facing state or a system service and a UseCase would only
  forward the same call. Follow the nearest feature's established pattern.
- Keep `LogManager` available as a static diagnostic utility at any layer.
- Put code used by both apps under `openclient-llm/Shared/`. Put genuinely platform-only app code in the corresponding
  target directory. Use `#if os(iOS)` or `#if os(macOS)` for small differences inside otherwise shared views.
- Do not move extension/widget code into Shared unless target membership and extension constraints are deliberately
  changed.
- Use `@Observable`, not `ObservableObject` or `@Published`, and keep explicit `@MainActor` on ViewModels.
- Prefer `async`/`await` and native throwing APIs. `Result` remains appropriate for configurable test doubles and stored
  outcomes.

## ViewModel Shape

Use the Event/State shape for screen ViewModels, while allowing feature-specific states and synchronous or asynchronous
event handling:

```swift
@Observable
@MainActor
final class FeatureViewModel {
    enum Event {
        case viewAppeared
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {}

    private(set) var state: State = .loading

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            state = .loaded(.init())
        }
    }
}
```

Extensions such as `ChatViewModel+Streaming.swift` are an established way to split a large feature while retaining one
ViewModel type. Do not force every type or helper into this template.

## Maintenance

- File System Synchronized Groups usually discover new files automatically, but verify target inclusion and platform
  compilation when adding files under a shared group.
- Update `ARCHITECTURE.md` when targets, top-level directories, feature modules, layer ownership, or platform strategy
  change. It is a structural overview, not an inventory that must list every source file.
- Keep detailed style, concurrency, testing, and SwiftUI rules in their focused specifications rather than duplicating
  them here.
