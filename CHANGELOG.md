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
- Unit tests for all ViewModels, UseCases, and Repositories
- SwiftLint integration via SPM
- Dark Mode support with semantic colors and CodeBlockBackground asset
- ChatGPT-inspired visual redesign: assistant messages with sparkles avatar, user messages with glass accent bubbles, empty state with centered icon and suggestion chips
- ConversationStartersManager with 8 suggestion prompts, randomly showing 4 per session
- "Thinking..." indicator with pulse animation below assistant messages while waiting for first token
- Streaming cursor (█) inline at the end of the last text block during response generation
- Glass effect input bar with capsule shape and animated send/stop buttons
- KeychainManager for secure storage of server URL and API key using iOS/macOS Keychain Services
- ResetAppDataUseCase to clear all persisted data (Keychain + UserDefaults) on first launch
- Automatic migration from UserDefaults to Keychain for existing users
- `deleteAll()` method on SettingsManager for full data cleanup
- MarkdownParser utility that splits assistant message content into typed blocks (`.text`, `.codeBlock`)
- CodeBlockView with monospaced font, horizontal scroll, language label, and one-tap copy button (UIPasteboard / NSPasteboard)
- Full Markdown block rendering in assistant messages: headings (H1–H3), lists, blockquotes, bold, italic, inline code, and links via `AttributedString` with `.full` syntax
- `LLMModel.Provider` enum (`.local` / `.cloud`) with classification logic based on `litellm_provider` from `/model/info`
- Local vs Cloud sections in Models screen, each sorted alphabetically
- Dynamic model icon: `desktopcomputer` for local models, `cloud` for cloud models
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
- LogManager debug logging system with emoji-differentiated log levels — only active in DEBUG builds
- Auto-generated conversation titles from the first user message
- Auto-persistence of conversations after streaming completes
- Token usage display: prompt, completion, and total token counts shown below assistant messages after streaming completes
- `TokenUsage` model on `ChatMessage` with automatic accumulation from streamed chunks
- `totalTokens` property on `Conversation` for usage tracking across all messages
- Model parameters UI: `ChatModelParametersView` sheet with sliders for temperature (0–2), max tokens (100–32768), and top P (0–1)
- `ModelParameters` model persisted per conversation with sensible defaults (temperature 0.7, maxTokens 4096, topP 1.0)
- Model parameters passed to `ChatCompletionRequest` on every message send
- Search conversations: `.searchable()` modifier on `ConversationListView` with real-time filtering by title
- `filteredConversations` in `ConversationListViewModel` with case-insensitive search
- iCloud sync via `CloudSyncManager` using `NSUbiquitousKeyValueStore`-backed iCloud Documents container; newer-wins merge strategy on load
- iCloud sync toggle in Settings with `isCloudSyncEnabled` on `SettingsManager`
- Audio transcription (Speech-to-Text) as voice dictation in the chat input bar; microphone button appears automatically when a Whisper-compatible model is detected; tap to record, tap again to stop and transcribe; transcribed text populates the input field
- `AudioRecorderManager` for platform audio recording with `AVAudioRecorder`
- `AudioTranscriptionRepository`, `TranscribeAudioUseCase` for `POST /v1/audio/transcriptions`
- Multipart form data upload support in `APIClient` for audio file uploads
- Raw data request support in `APIClient` for binary audio responses
- Text-to-Speech: "Read Aloud" button on assistant messages with play/stop toggle
- `TextToSpeechRepository`, `SynthesizeSpeechUseCase` for `POST /v1/audio/speech`
- `AudioPlayerManager` for playback of TTS audio data with `AVAudioPlayer`
- Show Token Usage toggle: new "Chat" section in Settings to show or hide the token count below each assistant response; stored in `UserDefaults`
- Pinned conversations: pin/unpin via context menu; pinned conversations appear in a dedicated "Pinned" section at the top of the list; `isPinned: Bool` on `Conversation`; `PinConversationUseCase`; `ConversationSection` extended with `.pinned` period
- Conversation tags: free-text tags via `ConversationTagsView` sheet; `tags: [String]` on `Conversation`; `UpdateConversationTagsUseCase`; horizontal filter-chips bar above the list with one-tap tag filtering
- Personal Context (User Profile): name, description, and extra context configured in a "Personal Context" sheet in Settings; `UserProfile` model persisted by `UserProfileManager` via `NSUbiquitousKeyValueStore` with `UserDefaults` fallback; profile injected into every conversation's effective system prompt via `ChatViewModel.buildEffectiveSystemPrompt()`
- `ChatInputBarView`: dedicated file for the chat input bar (text field, attachment menu, send/stop/mic/recording buttons, `AudioRecorderManager`), extracted from `ChatView` to keep both files under the 500-line SwiftLint limit
- Mock test doubles for all UseCases, Repositories, and Managers (164 unit tests total)

### Changed

- Settings screen: merged Connection and Save sections into a single Server section
- SettingsManager now delegates server URL and API key storage to KeychainManager instead of UserDefaults
- LaunchViewModel resets all app data when onboarding has not been completed (first launch / reinstall)
- `FetchModelsUseCase` now propagates `provider` from `/model/info`, with `owned_by` as fallback
- `ModelsRepository.fetchModelInfo()` maps `litellm_provider` to `LLMModel.Provider`
- ChatViewModel rewritten to support conversation lifecycle (create, load, persist, auto-title)
- ChatView updated with system prompt sheet, attachment pickers, and conversation loading
- HomeView: iOS uses TabView with NavigationStack (iPhone) / NavigationSplitView (iPad); macOS uses 3-column NavigationSplitView; `ModelsView` and `SettingsView` render in the `detail` column with `columnVisibility` switching to `.doubleColumn`
- MessageBubbleView: replaced text badges with image thumbnails (120pt rounded) and document cards; added context menu actions and TTS speak/stop button on assistant messages
- ChatCompletionRequest.content now supports multimodal encoding (text string or array of content parts)
- ChatRepository builds multimodal messages with base64 image and PDF text extraction
- `ChatRepository` returns `StreamChunk` (text + optional `TokenUsage`) instead of plain `String` tokens
- `StreamMessageUseCase` accepts optional `ModelParameters` for per-request parameter customization
- `ConversationRepository` integrates `CloudSyncManager` for automatic upload/download on save/load
- `SettingsViewModel` handles `cloudSyncToggled` event; `SettingsView` includes iCloud Sync section
- `APIClient` protocol extended with `multipartRequest` and `rawDataRequest` methods
- Audio transcription redesigned from a standalone tab into voice dictation in the chat input bar
- Chat model selector excludes TTS and transcription models; only chat/completion models shown
- Image generation integrated into chat flow: generated images appear as assistant message attachments in the conversation
- `ChatViewModel` split into extension files (`+ImageGeneration`, `+Transcription`) to stay under 500 lines; uses `persistConversation()` and `scheduleErrorDismiss()` shared across extensions
- Conversation list redesign: grouped into time sections (Today, Yesterday, This Week, Earlier); each row shows a Liquid Glass avatar, title + date, last message preview, and model badge pill; selection highlighted with accent-tinted glass background
- Model selector name truncated at 200pt in the middle (preserves provider prefix and model suffix)
- macOS `ConversationListView` uses `.listStyle(.sidebar)`; `.refreshable {}` guarded to iOS/iPadOS only

### Removed

- `AudioTranscriptionView` and `AudioTranscriptionViewModel` standalone screen and tab
- `ImageGenerationView` and `ImageGenerationViewModel` standalone screen and tab
- Dedicated "Generate Image" button from the chat input `+` menu; along with `GenerateImageUseCase`, `ImageGenerationRepository`, `GeneratedImage`, `ImageGenerationRequest`, `ImageGenerationResponse`, and related tests/mocks

### Fixed

- Chat screen turning black during streaming due to cascading `.smooth` animations on every token; token updates now use no animation, only message count changes animate
- Message entry transition simplified to `.opacity` to prevent layout thrashing during streaming
- Keyboard opening on top of chat messages without scrolling to the last message
- `StreamOptions.includeUsage` serialized as `"includeUsage"` (camelCase) instead of `"include_usage"` (snake_case), causing some cloud providers to reject streaming requests
- `ContentPart` multimodal messages included `"text": null` and `"image_url": null` when not applicable; providers like Anthropic and Gemini rejected these with 400 errors; fields now omitted via `encodeIfPresent`
- Assistant message text rendered without line breaks; single `\n` now normalized to `\n\n` before `AttributedString` rendering so paragraph breaks display correctly
- Generated images from chat completions now display correctly as inline attachments; previously stored but never rendered due to missing `attachmentsView` in `assistantMessageLayout`
- macOS: removed nested `NavigationStack` from `ChatView`, `ModelsView`, and `SettingsView`; `.navigationTitle` and `.toolbar` now propagate correctly to the `NSWindow` title bar, eliminating text-overflow and column-compression artefacts
- macOS `WebContentView`: replaced `NavigationStack`-wrapped layout with a native VStack + `WKWebView` with `WKNavigationDelegate`; Privacy Policy, Terms of Use, and Author links now load correctly

### Security

- Server URL and API key are no longer stored in plain text in UserDefaults
- Keychain items use `kSecAttrAccessibleAfterFirstUnlock` protection level