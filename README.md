<p align="center">
  <img src="assets/icon_radius.png" alt="OpenClient" width="128" />
</p>

<h1 align="center">OpenClient</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2026+%20|%20iPadOS%2026+%20|%20macOS%2026+-blue?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6+-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue?style=flat-square&logo=swift" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Xcode-26+-blue?style=flat-square&logo=xcode" alt="Xcode" />
</p>

## Description

Native Apple client for OpenAI-compatible LLM servers. Works out of the box with [LiteLLM](https://github.com/BerriAI/litellm) — a self-hosted proxy that connects to any LLM provider (Ollama, OpenAI, Anthropic, Groq, and more) — and also directly with [Ollama](https://ollama.com) using its built-in OpenAI-compatible endpoint (`/v1`). Just point the app at your server and start chatting.

## Technologies

| Technology | Purpose |
|-----------|---------|
| Swift 6+ | Language |
| SwiftUI | UI Framework |
| Liquid Glass | Design language (iOS 26+) |
| async/await | Concurrency |
| URLSession + SSE | Networking & streaming |
| Keychain | Secure storage |
| SwiftLint | Code linting |
| SF Symbols | Iconography |

## Architecture

```
openclient-llm/                    # iOS target
├── App/                           # iOS app entry point
├── Shared/                        # Shared code (iOS + macOS)
│   ├── Features/                  # Feature modules
│   │   ├── AudioTranscription/    # Speech-to-Text (integrated in chat input)
│   │   │   ├── UseCases/          # TranscribeAudioUseCase
│   │   │   ├── Repositories/      # AudioTranscriptionRepository
│   │   │   └── Models/            # Transcription domain model
│   │   ├── Chat/                  # Chat with SSE streaming and voice dictation
│   │   │   ├── Views/             # ChatView, ConversationListView, input bar, bubbles, pickers
│   │   │   ├── ViewModels/        # ChatViewModel, ConversationListViewModel
│   │   │   ├── UseCases/          # StreamMessage, Save/Load/Delete/Pin conversation, Tags
│   │   │   ├── Repositories/      # ChatRepository, ConversationRepository
│   │   │   └── Models/            # ChatMessage, Conversation, TokenUsage, ModelParameters
│   │   ├── Home/                  # TabView (iOS) / NavigationSplitView (macOS)
│   │   │   └── Views/             # HomeView — root layout for both platforms
│   │   ├── Launch/                # Initial routing (onboarding check)
│   │   │   ├── Views/             # LaunchView
│   │   │   ├── ViewModels/        # LaunchViewModel
│   │   │   └── UseCases/          # CheckOnboarding, ResetAppData, ConfigureVotice
│   │   ├── Models/                # LLM model listing
│   │   │   ├── Views/             # ModelsView (Local / Cloud sections)
│   │   │   ├── ViewModels/        # ModelsViewModel
│   │   │   ├── UseCases/          # FetchModelsUseCase
│   │   │   ├── Repositories/      # ModelsRepository
│   │   │   └── Models/            # LLMModel (Provider, Mode, Capability)
│   │   ├── Onboarding/            # Server setup wizard
│   │   │   ├── Views/             # OnboardingView
│   │   │   ├── ViewModels/        # OnboardingViewModel
│   │   │   ├── UseCases/          # TestConnection, SaveServerConfig, CompleteOnboarding
│   │   │   ├── Repositories/      # OnboardingRepository
│   │   │   └── Models/            # OnboardingStep
│   │   ├── Settings/              # Server config, preferences, personal context
│   │   │   ├── Views/             # SettingsView, UserProfileView
│   │   │   ├── ViewModels/        # SettingsViewModel, UserProfileViewModel
│   │   │   └── Models/            # UserProfile
│   │   └── TextToSpeech/          # Text-to-Speech playback
│   │       ├── UseCases/          # SynthesizeSpeechUseCase
│   │       └── Repositories/      # TextToSpeechRepository
│   ├── Core/
│   │   ├── Networking/            # APIClient, SSE streaming, multipart upload, DTOs
│   │   ├── Managers/              # Settings, Keychain, CloudSync, AudioPlayer,
│   │   │                          # AudioRecorder, ConversationStarters, UserProfile, Log
│   │   ├── Views/                 # Reusable cross-feature views
│   │   ├── Extensions/            # Swift/SwiftUI extensions
│   │   └── Utils/                 # Constants, MarkdownParser
│   └── Resources/
│       └── Localizable.xcstrings  # String catalog (all localized strings)
└── Resources/
    └── Assets.xcassets/           # iOS app icon, accent color, semantic colors

openclient-llm-macOS/              # macOS target
├── App/                           # macOS app entry point
├── Views/                         # macOS-only views (AppCommands — ⌘N New Chat)
└── Resources/
    └── Assets.xcassets/           # macOS app icon, accent color

openclient-llm-test/               # Unit tests
├── Core/                          # Manager tests (Keychain, etc.)
├── Features/                      # ViewModel, UseCase, Repository tests per feature
└── Mocks/                         # Protocol-based mock implementations
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
3. **Configure** your server URL in the app settings:
   - **LiteLLM**: `http://your-server:4000`
   - **Ollama** (direct): `http://your-server:11434/v1`
4. **Run** on your device or simulator

### Requirements

- Xcode 26+
- iOS 26+ / macOS 26+
- A running [LiteLLM](https://docs.litellm.ai/) server (local or remote), **or** a running [Ollama](https://ollama.com) instance (v0.1.24+ for OpenAI-compatible `/v1` endpoint)

### Self-hosting guides

If you need to set up the backend on your own server, these guides cover Docker Compose configurations, reference `.env` files, and common operational commands:

- [Ollama.md](Ollama.md) — Run Ollama with Docker (CPU and NVIDIA GPU)
- [LiteLLM.md](LiteLLM.md) — Run LiteLLM with Docker (Postgres, Traefik, local + cloud models)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to report issues, propose features, and submit pull requests.

## Author

**Arturo Carretero Calvo**

- [GitHub](https://github.com/ArtCC)

---

<p align="left">
  This project was developed entirely with <strong>Claude Sonnet 4.6</strong>, <strong>Visual Studio Code</strong> and <strong>Xcode</strong>.
</p>

---

<p align="left">
  <strong>Your AI. Your server. Your rules.</strong><br/><br/>
  OpenClient is built on the belief that generative AI should be something you control — not something that controls your data.<br/>
  Run local models entirely on your own hardware, or route cloud providers through your own self-hosted proxy.<br/>
  Either way, you decide what gets sent where — no vendor lock-in, no platform middleman, no data you didn't choose to share.<br/><br/>
  Open source. No tracking. Full control.
</p>