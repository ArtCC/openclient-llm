<p align="center">
  <img src="assets/icon_radius.png" alt="OpenClient LLM" width="128" />
</p>

<h1 align="center">OpenClient LLM</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2026+%20|%20iPadOS%2026+%20|%20macOS%2026+-blue?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6+-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue?style=flat-square&logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Xcode-26+-blue?style=flat-square&logo=xcode" alt="Xcode" />
</p>

## Description

Native Apple client for [LiteLLM](https://github.com/BerriAI/litellm), a self-hosted LLM proxy server. Connect to any LLM provider (Ollama, OpenAI, Anthropic, Groq, and more) through a single unified endpoint with a beautiful, native iOS, iPadOS, and macOS experience.

## Technologies

| Technology | Purpose |
|-----------|---------|
| Swift 6+ | Language |
| SwiftUI | UI Framework |
| Liquid Glass | Design language (iOS 26+) |
| async/await | Concurrency |
| URLSession + SSE | Networking & streaming |
| Keychain | Secure storage (API keys) |
| SwiftLint | Code linting |
| SF Symbols | Iconography |

## Architecture

```
openclient-llm/                    # iOS target
├── App/                           # iOS app entry point
│   └── OpenClientApp.swift
├── Shared/                        # Shared code (iOS + macOS)
│   ├── Features/                  # Feature modules
│   │   ├── Chat/                  # Chat with SSE streaming
│   │   │   ├── Views/             # ChatView, MessageBubbleView
│   │   │   ├── ViewModels/        # ChatViewModel (Event/State)
│   │   │   ├── UseCases/          # SendMessage, StreamMessage
│   │   │   ├── Repositories/      # ChatRepository
│   │   │   └── Models/            # ChatMessage
│   │   ├── Home/                  # TabView (iOS) / SplitView (macOS)
│   │   │   └── Views/             # HomeView
│   │   ├── Launch/                # Initial routing
│   │   │   ├── Views/             # LaunchView
│   │   │   ├── ViewModels/        # LaunchViewModel
│   │   │   └── UseCases/          # CheckOnboarding, ResetAppData
│   │   ├── Models/                # LLM model listing
│   │   │   ├── Views/             # ModelsView
│   │   │   ├── ViewModels/        # ModelsViewModel
│   │   │   ├── UseCases/          # FetchModelsUseCase
│   │   │   ├── Repositories/      # ModelsRepository
│   │   │   └── Models/            # LLMModel
│   │   ├── Onboarding/            # Server setup wizard
│   │   │   ├── Views/             # OnboardingView
│   │   │   ├── ViewModels/        # OnboardingViewModel
│   │   │   ├── UseCases/          # TestConnection, SaveConfig, Complete
│   │   │   ├── Repositories/      # OnboardingRepository
│   │   │   └── Models/            # OnboardingStep
│   │   └── Settings/              # Server configuration
│   │       ├── Views/             # SettingsView
│   │       └── ViewModels/        # SettingsViewModel
│   ├── Core/
│   │   ├── Networking/            # API client, SSE streaming
│   │   │   └── Models/            # Request/response DTOs
│   │   ├── Managers/              # Settings, Keychain, conversation starters
│   │   ├── Views/                 # Reusable views
│   │   ├── Extensions/            # Swift/SwiftUI extensions
│   │   └── Utils/                 # Constants, shared utilities
│   └── Resources/
│       └── Localizable.xcstrings  # Localization
└── Resources/
    └── Assets.xcassets/           # iOS assets, accent color, app icon

openclient-llm-macOS/              # macOS target
├── App/                           # macOS app entry point
│   └── OpenClientApp.swift
└── Resources/
    └── Assets.xcassets/           # macOS assets, accent color, app icon

openclient-llm-test/               # Unit tests
├── Core/
│   └── Managers/                  # KeychainManager tests
├── Features/
│   ├── Chat/                      # ChatViewModel, UseCase tests
│   ├── Launch/                    # LaunchViewModel, UseCase tests
│   ├── Models/                    # ModelsViewModel, UseCase tests
│   ├── Onboarding/                # OnboardingViewModel, UseCase tests
│   └── Settings/                  # SettingsViewModel tests
└── Mocks/                         # Mock implementations
```

## Usage

1. **Clone** the repository:
   ```bash
   git clone https://github.com/ArtCC/openclient-llm.git
   ```
2. **Open** in Xcode:
   ```bash
   cd openclient-llm
   open openclient-llm.xcodeproj
   ```
3. **Configure** your LiteLLM server URL in the app settings
4. **Run** on your device or simulator

### Requirements

- Xcode 26+
- iOS 26+ / macOS 26+
- A running [LiteLLM](https://docs.litellm.ai/) server (local or remote)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Author

**Arturo Carretero Calvo**

- [GitHub](https://github.com/ArtCC)