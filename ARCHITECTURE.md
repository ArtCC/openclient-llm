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
│   │   ├── Managers/
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
- **`#if os(iOS)` / `#if os(macOS)`** — Used inside shared views for platform-specific UI variations.