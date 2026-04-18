# Architecture

OpenClient follows **MVVM + UseCase + Repository + Manager** with Swift strict concurrency and `async/await`.

```
View → ViewModel → UseCase → Repository → APIClient / LocalStorage
                      ↑
                   Manager (transversal services)
```

## Project Structure

```
openclient-llm/                    # iOS target
├── App/
├── Shared/                        # Shared code (iOS + macOS)
│   ├── Features/
│   │   ├── AudioTranscription/
│   │   │   ├── Models/
│   │   │   ├── Repositories/
│   │   │   └── UseCases/
│   │   ├── Chat/
│   │   │   ├── Models/
│   │   │   ├── Repositories/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Home/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Launch/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Models/
│   │   │   ├── Models/
│   │   │   ├── Repositories/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Onboarding/
│   │   │   ├── Models/
│   │   │   ├── Repositories/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── PromptTemplates/
│   │   │   ├── Models/
│   │   │   ├── Repositories/
│   │   │   ├── UseCases/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Settings/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   └── TextToSpeech/
│   │       ├── Models/
│   │       ├── Repositories/
│   │       └── UseCases/
│   ├── Core/
│   │   ├── Extensions/
│   │   │   ├── Foundation/
│   │   │   └── SwiftUI/
│   │   ├── Managers/              # ShareManager, SpotlightManager, ShortcutManager…
│   │   ├── Models/                # ShareExtensionItem (shared with extension)
│   │   ├── Networking/
│   │   │   └── Models/
│   │   ├── Utils/
│   │   └── Views/
│   └── Resources/
└── Resources/

openclient-llm-macOS/              # macOS target
├── App/
├── Views/
└── Resources/

ShareExtension/                    # iOS Share Extension target
├── ShareViewController.swift      # SLComposeServiceViewController — extracts & saves payload
├── ShareExtensionItem.swift       # Codable payload model (mirrors Shared/Core/Models/)
├── ShareExtensionStore.swift      # Write-side: persists payload to App Group container
├── ShareExtension.entitlements    # App Groups: group.com.artcc.openclient-llm
└── Info.plist                     # NSExtensionActivationRule for text/URL/image/PDF

openclient-llm-test/               # Unit tests
├── Core/
│   └── Managers/
├── Features/
│   ├── AudioTranscription/
│   ├── Chat/
│   ├── Home/
│   ├── Launch/
│   ├── Models/
│   ├── Onboarding/
│   ├── PromptTemplates/
│   └── Settings/
└── Mocks/                         # MockXxx per protocol, @unchecked Sendable
```

## Layer Responsibilities

| Layer | Responsibility |
|---|---|
| **View** | SwiftUI views. Observes ViewModel state, sends events. No business logic. |
| **ViewModel** | `@Observable @MainActor`. Event/State pattern. Coordinates UseCases. |
| **UseCase** | Single business operation. Calls Repositories and Managers. |
| **Repository** | Data access abstraction (network, cache, local storage). Protocol-based for testability. |
| **Manager** | Transversal services shared across features (auth, settings, connectivity). |
| **APIClient** | Single networking layer via `URLSession` + `async/await`. Communicates with LiteLLM. |

## Platform Strategy

- **`Shared/`** — All business logic, models, networking, ViewModels, UseCases, Repositories, Managers. Referenced by both targets.
- **`openclient-llm/`** (outside Shared) — iOS/iPadOS-specific views, app entry point, iOS resources.
- **`openclient-llm-macOS/`** — macOS-specific views, app entry point, macOS resources. No shared logic duplicated here.
- **`ShareExtension/`** — Share Extension target (iOS/iPadOS). Shares `ShareExtensionItem` model and `ShareExtensionStore` write-side with the main app via the App Group container (`group.com.artcc.openclient-llm`). Does not link against Shared code directly to keep the extension lightweight.
- **`#if os(iOS)` / `#if os(macOS)`** — Used inside shared views for platform-specific UI variations.

## Share Extension Data Flow

```
Other App (Telegram, Safari…)
    └── Share Sheet → ShareViewController (extension)
                          ├── Writes ShareExtensionItem JSON → App Group container
                          ├── Writes attachment binaries   → App Group container/SharePending/
                          └── Opens openclient://share

openclient://share → SceneDelegate.handle(url:)
    └── ShareManager.shared.hasPendingShare = true

HomeView.onChange(hasPendingShare)
    └── HomeViewModel.send(.shareItemReceived)
            ├── ShareExtensionStore.load()   → reads JSON
            ├── pendingShareItem = item
            └── pendingConversation = Conversation(modelId: …)

HomeView.onChange(pendingConversation)
    └── ChatView(shareItem: item)
            └── .task → processShareItemIfNeeded()
                    ├── viewModel.send(.inputChanged(text/url))
                    ├── viewModel.send(.attachmentAdded(…)) per binary
                    └── ShareExtensionStore.clear()
```