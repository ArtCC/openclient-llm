# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-01

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
- macOS support with 3-column NavigationSplitView (sidebar → content → detail)
- macOS menu bar commands with `AppCommands` (⌘N New Chat)
- macOS minimum window size (800×600) with default size (1000×700)
- iPadOS adaptive split view layout in the Chats tab
- Keyboard shortcuts: ⌘N for new chat
- FocusedValues integration for menu bar ↔ view communication
- Local network access support (NSBonjourServices + NSLocalNetworkUsageDescription)
- Localization for 10 languages: English, Spanish, French, Italian, German, Portuguese (PT), Japanese, Dutch, Greek, Swedish
- Unit tests for all ViewModels, UseCases, and Repositories (60 tests)
- SwiftLint integration via SPM
- Dark Mode support with semantic colors and CodeBlockBackground asset
- ChatGPT-inspired visual redesign: assistant messages with sparkles avatar, user messages with glass accent bubbles, empty state with centered icon and suggestion chips
- ConversationStartersManager with 8 suggestion prompts, randomly showing 4 per session
- "Thinking..." indicator with pulse animation below assistant messages while waiting for first token
- Streaming cursor (█) inline at the end of the last text block during response generation
- Glass effect input bar with capsule shape and animated send/stop buttons
- Chat visual style instruction document for agent context
- Refactored instruction documents with generic/app-specific separation
- KeychainManager for secure storage of server URL and API key using iOS/macOS Keychain Services
- ResetAppDataUseCase to clear all persisted data (Keychain + UserDefaults) on first launch
- Automatic migration from UserDefaults to Keychain for existing users
- `deleteAll()` method on SettingsManager for full data cleanup
- Unit tests for KeychainManager and ResetAppDataUseCase
- MockKeychainManager and MockResetAppDataUseCase test doubles
- MarkdownParser utility that splits assistant message content into typed blocks (`.text`, `.codeBlock`)
- CodeBlockView with monospaced font, horizontal scroll, language label, and one-tap copy button (UIPasteboard / NSPasteboard)
- Full Markdown block rendering in assistant messages: headings (H1–H3), lists, blockquotes, bold, italic, inline code, and links via `AttributedString` with `.full` syntax
- `LLMModel.Provider` enum (`.local` / `.cloud`) with classification logic based on `litellm_provider` from `/model/info`
- Local vs Cloud sections in Models screen, each sorted alphabetically
- Dynamic model icon: `desktopcomputer` for local models, `cloud` for cloud models
- Selected model highlighted with a 1.5pt accent-color border instead of a tinted background
- Smart auto-scroll in chat: follows new content only when the user is at the bottom; pauses when user scrolls up and resumes when they reach the bottom again
- Chat message area capped at 760pt max width, centered horizontally (better iPad/Mac layout)
- Conversation persistence: save/load conversations locally using Codable + FileManager (Documents/Conversations/)
- Conversation list screen with past conversations, swipe-to-delete, pull-to-refresh, and empty state
- New conversation creation from the conversation list, using the selected model from settings
- Configurable system prompt per conversation via toolbar sheet
- Copy/share messages: context menu on message bubbles with Copy and ShareLink actions
- Vision support: attach images from photo library; sent as base64 image_url content parts to the chat completions API
- Document understanding: attach PDFs; text extracted via PDFKit and sent as context to the chat completions API
- AttachmentPickerView with PhotosPicker (images) and fileImporter (PDFs) integration
- Multimodal content support in networking layer (text + image_url content parts in ChatCompletionMessage)
- ConversationRepository with FileManager-based CRUD (atomic writes, ISO8601 date encoding)
- ConversationListViewModel with Event/State pattern for conversation management
- Attachment model on ChatMessage (type, fileName, data) with Codable support
- Pending attachments bar in chat input area with remove capability
- Attachment thumbnails: image attachments shown as 120pt rounded previews inline in chat messages; PDF attachments shown as icon + filename cards with glass effect
- LogManager debug logging system with emoji-differentiated log levels (🔍 DEBUG, ℹ️ INFO, ⚠️ WARNING, ❌ ERROR, 🌐 NETWORK, ✅ SUCCESS) — only active in DEBUG builds, includes timestamp, file, function, and line number
- Auto-generated conversation titles from the first user message
- Auto-persistence of conversations after streaming completes
- Unit tests for ConversationListViewModel, conversation persistence, system prompt, and attachment handling
- Mock test doubles for ConversationRepository, LoadConversationsUseCase, SaveConversationUseCase, DeleteConversationUseCase
- Token usage display: prompt, completion, and total token counts shown below assistant messages after streaming completes
- `TokenUsage` model on `ChatMessage` with automatic accumulation from streamed chunks
- `totalTokens` property on `Conversation` for usage tracking across all messages
- Model parameters UI: `ChatModelParametersView` sheet with sliders for temperature (0–2), max tokens (100–32768), and top P (0–1)
- `ModelParameters` model persisted per conversation with sensible defaults (temperature 0.7, maxTokens 4096, topP 1.0)
- Model parameters passed to `ChatCompletionRequest` on every message send
- Search conversations: `.searchable()` modifier on `ConversationListView` with real-time filtering by title
- `filteredConversations` in `ConversationListViewModel` with case-insensitive search
- iCloud sync via `CloudSyncManager` using iCloud Documents container (`NSUbiquitousKeyValueStore`-backed)
- `CloudSyncManager` syncs conversations on save and merges remote changes on load (newer-wins strategy)
- iCloud sync toggle in Settings with `isCloudSyncEnabled` on `SettingsManager`
- Image generation feature: `ImageGenerationView` with prompt input, model picker, size selector, and image count
- Generated images displayed in a gallery grid with context menu actions (share, copy)
- `ImageGenerationRepository`, `GenerateImageUseCase`, `ImageGenerationViewModel` with Event/State pattern
- `ImageGenerationRequest`/`ImageGenerationResponse` API models for `POST /v1/images/generations`
- Audio transcription (Speech-to-Text) integrated as voice dictation in the chat input bar; microphone button appears automatically when a Whisper-compatible model is detected on the server; tap to record, tap again to stop and transcribe; transcribed text populates the input field ready to edit or send
- `AudioRecorderManager` for platform audio recording with `AVAudioRecorder`
- `AudioTranscriptionRepository`, `TranscribeAudioUseCase` for `POST /v1/audio/transcriptions`
- `AudioTranscriptionRequest`/`AudioTranscriptionResponse` API models for `POST /v1/audio/transcriptions`
- Chat model selector now only shows chat/completion models, excluding TTS and transcription models
- Multipart form data upload support in `APIClient` for audio file uploads
- Raw data request support in `APIClient` for binary audio responses
- Text-to-Speech: "Read Aloud" button on assistant messages with play/stop toggle
- `TextToSpeechRepository`, `SynthesizeSpeechUseCase` for `POST /v1/audio/speech`
- `AudioPlayerManager` for playback of TTS audio data with `AVAudioPlayer`
- `TextToSpeechRequest` API model with voice and speed parameters
- Image Generation tab in HomeView (iOS TabView, macOS sidebar)
- Unit tests for ImageGenerationViewModel and TTS integration in ChatViewModel
- Mock test doubles for GenerateImageUseCase, TranscribeAudioUseCase, SynthesizeSpeechUseCase, CloudSyncManager

### Changed

- Settings screen: merged Connection and Save sections into a single Server section for a cleaner layout
- SettingsManager now delegates server URL and API key storage to KeychainManager instead of UserDefaults
- LaunchViewModel resets all app data when onboarding has not been completed (first launch / reinstall)
- `FetchModelsUseCase` now propagates `provider` from `/model/info`, with `owned_by` as fallback
- `ModelsRepository.fetchModelInfo()` maps `litellm_provider` to `LLMModel.Provider`
- `LazyVStack` in chat uses `.padding(.horizontal, 16)` only (removed unneeded vertical padding)
- Assistant message spacing increased to 8pt between blocks for readability
- ChatViewModel rewritten to support conversation lifecycle (create, load, persist, auto-title)
- ChatView updated with system prompt sheet, attachment pickers, and conversation loading
- HomeView refactored: iOS uses TabView with NavigationStack (iPhone) / NavigationSplitView (iPad); macOS uses 3-column NavigationSplitView with sidebar selection
- MessageBubbleView attachments: replaced text badges with image thumbnails (120pt rounded) and document cards (icon + filename + type label)
- MessageBubbleView enhanced with context menu actions and attachment display
- ChatCompletionRequest.content now supports multimodal encoding (text string or array of content parts)
- ChatRepository builds multimodal messages with base64 image and PDF text extraction
- macOS app entry point includes `.commands {}` and `.frame(minWidth:minHeight:)` for native window behavior
- `ChatRepository` returns `StreamChunk` (text + optional `TokenUsage`) instead of plain `String` tokens
- `StreamMessageUseCase` accepts optional `ModelParameters` for per-request parameter customization
- `ChatViewModel` tracks `isSpeaking` and `speakingMessageId` state for TTS playback coordination
- `MessageBubbleView` receives TTS action closures and displays speak/stop button on assistant messages
- `ConversationListView` iterates over `filteredConversations` instead of raw `conversations` for search support
- `ConversationRepository` integrates `CloudSyncManager` for automatic upload/download on save/load
- `SettingsViewModel` handles `cloudSyncToggled` event to persist iCloud sync preference
- `SettingsView` includes iCloud Sync section with toggle control
- `APIClient` protocol extended with `multipartRequest` and `rawDataRequest` methods
- HomeView updated with Image Generation and Audio Transcription tabs for iOS and macOS
- Audio transcription (Speech-to-Text) redesigned from a standalone tab into a voice dictation feature integrated directly in the chat input bar; the microphone button appears automatically when the server exposes a Whisper-compatible model; removed file import and transcription history; transcribed text populates the input field ready to send
- Chat model selector now excludes TTS and transcription models; only chat/completion models are shown
- Image generation redesigned from a standalone tab into a chat action; a wand button (✦) appears in the input bar when the server exposes an image generation model (e.g. DALL·E, gpt-image-1); generated images appear as assistant message attachments inline in the conversation
- `ChatViewModel` extended with `generateImage()` and `performImageGeneration()` (extracted to `ChatViewModel+ImageGeneration.swift`) to handle image generation events and state
- `ChatViewModel` split into extension files: `ChatViewModel+ImageGeneration.swift` and `ChatViewModel+Transcription.swift` to keep the main file under 500 lines
- `ImageGenerationRepository.generateViaImagesEndpoint` now supports `url` fallback when `b64_json` is nil, downloading image data from the response URL
- Chat `LoadedState` includes `imageModel: LLMModel?` and `isGeneratingImage: Bool` for image generation coordination
- `ChatViewModel` uses `persistConversation()` and `scheduleErrorDismiss()` as internal-scoped helpers shared across extension files

### Removed

- `AudioTranscriptionView` and `AudioTranscriptionViewModel` standalone screen
- Transcription tab from iOS TabView and macOS sidebar
- `ImageGenerationView` and `ImageGenerationViewModel` standalone screen
- Images tab from iOS TabView and macOS sidebar

### Fixed

- Chat screen turning black during streaming due to cascading `.smooth` animations on every token; token updates now use no animation, only message count changes animate
- Message entry transition simplified to `.opacity` to prevent layout thrashing during streaming
- Keyboard opening on top of chat messages without scrolling to the last message

### Security

- Server URL and API key are no longer stored in plain text in UserDefaults
- Keychain items use `kSecAttrAccessibleAfterFirstUnlock` protection level

### Bug Fixes (post-release)

- `StreamOptions.includeUsage` was serialized as `"includeUsage"` (camelCase) instead of `"include_usage"` (snake_case), causing some cloud providers to reject streaming requests with 400/500 errors
- `ContentPart` multimodal messages included `"text": null` and `"image_url": null` fields when not applicable; providers like Anthropic and Gemini rejected these with 400 errors; fields are now omitted when absent via `encodeIfPresent`
- Assistant message text rendered without line breaks because `AttributedString(markdown:)` collapses single `\n` into spaces per CommonMark spec; single newlines are now normalized to double newlines before rendering so paragraph breaks display correctly

### Improvements (post-release)

- **Show Token Usage toggle**: New "Chat" section in Settings with a toggle to show or hide the token count displayed below each assistant response; preference stored in `UserDefaults` and respected in `MessageBubbleView`
- **Conversation list redesign**: Conversations are now grouped into time sections (Today, Yesterday, This Week, Earlier); each row shows a Liquid Glass avatar icon, title + date on the same line, last message preview, and a model badge pill; selection highlighted with an accent-tinted glass background; list uses `.plain` style for a cleaner layout aligned with the rest of the app