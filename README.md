# OpenClient LLM

![Platform](https://img.shields.io/badge/Platform-iOS%20|%20iPadOS%20|%20macOS-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6+-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)
![Xcode](https://img.shields.io/badge/Xcode-16+-blue?style=flat-square&logo=xcode)

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
│   │   └── <Feature>/
│   │       ├── Views/             # SwiftUI views
│   │       ├── ViewModels/        # @Observable + Event/State
│   │       ├── UseCases/          # Business logic
│   │       ├── Repositories/      # Data access
│   │       └── Models/            # Domain models
│   ├── Core/
│   │   ├── Networking/            # API client, SSE streaming
│   │   ├── Managers/              # Auth, settings, connectivity
│   │   ├── Extensions/            # Swift/SwiftUI extensions
│   │   └── Utils/                 # Shared utilities
│   └── Resources/
│       └── Localizable.xcstrings  # Localization (en, es, it, de, pt-PT)
└── Resources/
    └── Assets.xcassets/           # iOS assets, accent color, app icon

openclient-llm-macOS/              # macOS target
├── App/                           # macOS app entry point
│   └── OpenClientApp.swift
└── Resources/
    └── Assets.xcassets/           # macOS assets, accent color, app icon

openclient-llm-test/               # Unit tests
└── <Feature>Tests/                # Tests by feature
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

- Xcode 16+
- iOS 18+ / macOS 15+
- A running [LiteLLM](https://docs.litellm.ai/) server (local or remote)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Author

**Arturo Carretero Calvo**

- [GitHub](https://github.com/ArtCC)