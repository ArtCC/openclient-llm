# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-30

### Added

- KeychainManager for secure storage of server URL and API key using iOS/macOS Keychain Services
- ResetAppDataUseCase to clear all persisted data (Keychain + UserDefaults) on first launch
- Automatic migration from UserDefaults to Keychain for existing users
- `deleteAll()` method on SettingsManager for full data cleanup
- Unit tests for KeychainManager and ResetAppDataUseCase
- MockKeychainManager and MockResetAppDataUseCase test doubles

### Changed

- SettingsManager now delegates server URL and API key storage to KeychainManager instead of UserDefaults
- LaunchViewModel resets all app data when onboarding has not been completed (first launch / reinstall)

### Security

- Server URL and API key are no longer stored in plain text in UserDefaults
- Keychain items use `kSecAttrAccessibleAfterFirstUnlock` protection level

## [1.0.0] - 2026-03-30

### Added

- Initial project setup with Xcode and SwiftUI
- GitHub Copilot instructions for agent context
- Onboarding flow with server configuration wizard (URL, API key, connection test)
- Chat with real-time SSE streaming via LiteLLM API
- Model listing and selection from LiteLLM server
- Persistent model selection across sessions
- Settings screen with server configuration and connection testing
- Liquid Glass design language applied across the UI (iOS 26+)
- Glass effect on chat input bar, assistant message bubbles, onboarding elements
- Glass prominent buttons in onboarding flow
- macOS support with NavigationSplitView sidebar layout
- Local network access support (NSBonjourServices + NSLocalNetworkUsageDescription)
- Localization for 10 languages: English, Spanish, French, Italian, German, Portuguese (PT), Japanese, Dutch, Greek, Swedish
- Unit tests for all ViewModels, UseCases, and Repositories (60 tests)
- SwiftLint integration via SPM
- Dark Mode support with semantic colors
- ChatGPT-inspired visual redesign: assistant messages with sparkles avatar, user messages with glass accent bubbles, empty state with centered icon and suggestion chips
- ConversationStartersManager with 8 suggestion prompts, randomly showing 4 per session
- "Thinking..." indicator with pulse animation below assistant messages while waiting for first token
- Streaming cursor (▌) appended to assistant messages during response generation
- Glass effect input bar with capsule shape and animated send/stop buttons
- Chat visual style instruction document for agent context
- Refactored instruction documents with generic/app-specific separation