# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## [1.0.2-build-20] - 2026-04-10

### Added

- **Media & Files gallery** — "Media & Files" entry in the chat toolbar menu opens a sheet with two sections: images displayed in a `LazyVGrid` of square thumbnails (rendered from persisted `Data`, no network required) and documents listed by file name and date; tapping an image opens `ImagePreviewView`; tapping a document opens a `PDFPreviewView` powered by `PDFKitRepresentable` (iOS & macOS); both support a "Go to message" button that dismisses the sheet and scrolls to the originating message
- **Favourite messages** — long-pressing any message shows a context menu option to mark/unmark it as a favourite (`isFavourite: Bool` in `ChatMessage`, persisted via `Codable` + `FileManager`); "Favourites" entry in the chat toolbar menu opens `ChatFavouritesView`, a sheet listing all favourited messages with role icon, text preview, and date; tapping a row scrolls directly to the message
- **macOS menu bar companion** — persistent `NSStatusItem` (`message.circle.fill`) in the macOS menu bar that opens a 380×540 `NSPopover` containing a full `ChatView` with streaming; "Open in App" button activates the main window; state (model, API key, base URL) shared via existing managers; initialised through `AppDelegate` + `@NSApplicationDelegateAdaptor`

### Changed

- Chat toolbar unified: the three individual action buttons (`square.and.arrow.up`, `slider.horizontal.3`, `text.bubble`) replaced by a single `Menu` with `ellipsis.circle` label on both iOS and macOS — options listed alphabetically: Export, Favourites, Media & Files (conditional on attachments), Model Parameters, System Prompt
- `scrollToFavouriteId` renamed to `scrollToMessageId` in `ChatView` to serve both Favourites and Media & Files scroll-to-message navigation

## [1.0.1-build-19] - 2026-04-09

### Added

- Ollama model capability detection via `litellm_params.model` prefix fallback — when `model_info:` is absent in LiteLLM config, the provider is inferred from the `ollama/` or `ollama_chat/` prefix; capabilities are supplemented via Ollama's native `/api/show` using the `api_base` from `litellm_params`

### Changed

- Capability tags in the model list cell are now sorted alphabetically by label

### Fixed

- Ollama capability detection failed when `model_info:` block was omitted from LiteLLM `config.yaml` — the app now falls back to `litellm_params.model` prefix to identify Ollama-backed models
- Ollama `/api/show` requests used `host.docker.internal` (from `litellm_params.api_base`) which is unreachable from the client device — fixed by using the IP configured in `api_base`; `LiteLLM.md` updated to document this requirement

## [1.0.1-build-18] - 2026-04-08

### Added

- Background streaming continuation — when the app moves to background while a model is responding, the stream continues using `UIApplication.beginBackgroundTask` (up to ~30 s); the partial response is saved and a local notification is sent when the response completes or the time budget expires
- `BackgroundTaskManager` — iOS manager wrapping `UIBackgroundTaskIdentifier` lifecycle (`beginTask` / `endTask`) with a macOS no-op stub
- `LocalNotificationManager` — shared manager using `UNUserNotificationCenter` to schedule "Response ready" and "Response interrupted" local notifications
- `StreamingBackgroundUseCase` — use case that begins and ends the background task around streaming calls in `ChatViewModel`
- `NotifyStreamingCompletedUseCase` — use case that fires a local notification when streaming finishes while the app is in background, or unconditionally when the background time budget expires
- `NotificationPermissionUseCase` — use case that requests `UNUserNotificationCenter` authorization; called after the user completes or skips Onboarding (not at app launch)
- Non-blocking LiteLLM server detection via `GET /health/readiness` — shown after "Test Connection" or "Save" in Settings, and after "Test Connection" or advancing to the next step in Onboarding; displays an informational hint below the server field when the server is not identified as LiteLLM
- `CheckLiteLLMHealthUseCase` — fires a lightweight, non-blocking `GET /health/readiness` call and returns `true` only when the response contains the `litellm_version` field (exclusive to LiteLLM proxy)
- `showLiteLLMHint` flag in `SettingsViewModel.LoadedState` and `OnboardingViewModel.LoadedState` — set to `true` when the connected server is not identified as LiteLLM
- `checkLiteLLMHealth(serverURL:)` method on `OnboardingRepository` / `OnboardingRepositoryProtocol`
- Tool system prompt in agent mode — instructs the model about the `web_search` tool, when to use it, how to cite sources, and allows any response format (Markdown, lists, code blocks, etc.)
- `ToolExecutionResult` value type replacing the plain `String` return of tool execution — carries `text` and optional `searchResults: [LiteLLMSearchResult]?` so agent tool results can surface sources in the UI
- `AgentEvent.toolCallCompleted` now includes `searchResults: [LiteLLMSearchResult]?` so web search results from the agentic loop are propagated to `ChatMessage.webSearchResults` and displayed in the sources disclosure group

### Changed

- Web search simplified to a **single method**: agent loop with `web_search` tool via `/v1/search` — removed native `web_search_options` path entirely
- `WebSearchOptions` struct removed from `ChatCompletionRequest` along with the `webSearchOptions` field and its propagation through `ChatRepository`, `StreamMessageUseCase`, and `ChatViewModel+Streaming`
- `LLMModel.Capability.nativeWebSearch` removed — web search capability is now determined solely by `.functionCalling`
- `ModelsRepository` no longer maps `model_info.supports_web_search` to a capability
- Globe button in `ChatInputBarView` now checks only `.functionCalling` (accent = supported, red = unsupported)
- `streamWithWebSearch` reduced from 3 branches (agent / native / none) to 2 (agent / regular streaming)
- `SendMessageContext` no longer carries `providerName` — provider-specific routing eliminated

### Fixed

- Agent mode performed a redundant second LLM request after receiving a `finish_reason: "stop"` response — removed `streamFinalResponse()` and the final answer is now emitted directly from `choice.message.content` as a single token
- Web search sources were never shown after agent tool calls — `WebSearchTool` now returns results via `ToolExecutionResult`, which are merged into `ChatMessage.webSearchResults` by `applyAgentEvent`
- Regular OpenAI models (`gpt-5`, `gpt-4.1`, `gpt-5.4-mini`) no longer receive `web_search_options` that caused HTTP 400 — the native path was removed entirely
- Agent loop comment corrected from "responds in plain text" to "generates a natural response"
- Quick Action cold launch (app fully closed) never triggered navigation — `onChange(of: pendingAction)` does not fire on the initial value set by `SceneDelegate` before `HomeView` exists; added `.task` to `HomeView` that reads `pendingAction` on first appear and consumes it after a 300 ms stabilisation delay
- Quick Action "New Chat" navigation invisible when launched from a non-chats tab — `selectedTab = .chats` and `newChatShortcutTriggered` were dispatched in the same render frame; added a 350 ms async delay so the tab-switch animation completes before the navigation push fires

## [1.0.0-build-17] - 2026-04-06

### Added

- App icon quick actions on iOS and iPadOS: long-press the app icon to reveal "New Chat" (opens a blank conversation) and "Search" (navigates to the search tab) via `UIApplicationShortcutItem` declared statically in `Info.plist`
- `ShortcutManager` — `@Observable @MainActor` singleton tracking the pending `ShortcutAction` (`newChat`, `search`); consumed by `HomeView` via `@State`; wrapped in `#if os(iOS)`
- `AppDelegate` (iOS) — `UIApplicationDelegate` routing the system shortcut callback to `ShortcutManager.shared`; registered via `@UIApplicationDelegateAdaptor`; guarded with `#if canImport(UIKit)` as the macOS target also compiles `openclient-llm/App/`
- Spotlight search for iOS, iPadOS, and macOS: conversations indexed in CoreSpotlight on save and deindexed on delete; tapping a Spotlight result opens the app directly in that conversation via `NSUserActivity` continuation
- `SpotlightManager` — `nonisolated struct Sendable` using `CSSearchableIndex` to index/deindex conversations with title and a 160-character snippet of the last message; indexes run fire-and-forget on a background `Task.detached`
- `SaveConversationUseCase` calls `SpotlightManager.index` as a background side-effect after persisting
- `DeleteConversationUseCase` calls `SpotlightManager.deindex` after deleting
- `HomeView` handles `NSUserActivity` continuation from Spotlight via `.onContinueUserActivity(SpotlightManager.activityType)` on iOS, iPadOS, and macOS; handles `ShortcutManager.pendingAction` changes via `.onChange` on iOS

### Fixed

- Keyboard covering the bottom TextField in the Personal Context screen — removed `.ignoresSafeArea(.keyboard, edges: .bottom)` which suppressed SwiftUI's native keyboard avoidance in `Form`

### Changed

- Personal Context "Description" field character limit raised from 200 to 500

## [1.0.0-build-16] - 2026-04-05

### Added

- Apple on-device Speech Recognition as a built-in STT option — always available in the Speech to Text section of the Models screen without requiring a LiteLLM Whisper model
- `LLMModel.appleSpeechRecognition` sentinel (ID `apple-speech-recognition`, provider local, mode `.audioTranscription`) prepended to the STT model list at load and refresh
- `AppleSpeechRecognitionManager` wrapping `SFSpeechRecognizer` with on-device recognition and async permission request
- `AppleAudioTranscriptionRepository` implementing `AudioTranscriptionRepositoryProtocol` via `AppleSpeechRecognitionManager`
- `TranscribeAudioUseCase` now routes to Apple STT or LiteLLM based on the selected model ID
- Microphone button in the chat input bar is now always visible — Apple STT is used as fallback when no LiteLLM STT model is configured
- `NSSpeechRecognitionUsageDescription` permission key added to iOS and macOS targets
- `MockAppleSpeechRecognitionManager` test double
- 3 new unit tests covering Apple STT default selection and mic always-present behaviour
- Web browsing via LiteLLM Search API (≥ v1.78.7): globe button in the chat input bar triggers a `POST /v1/search/{tool_name}` call before each message and injects the top results as system context so the model can cite sources
- `WebSearchUseCase` (`WebSearchUseCaseProtocol`) and `SearchModels` (`LiteLLMSearchRequest`, `LiteLLMSearchResponse`, `LiteLLMSearchResult`) for the search pipeline
- `APIClient.searchRequest(toolName:body:)` method added to the protocol and implementation
- `ChatMessage.webSearchResults` field stores the search results associated with an assistant reply
- `ChatViewModel` extended with `isWebSearchEnabled` / `isSearchingWeb` state, `.webSearchToggled` event, and graceful fallback when search fails
- `ChatViewModel+WebSearch` extension with `toggleWebSearch()` and `buildWebSearchContext(results:)` (top-5 Markdown citations)
- `ChatInputBarView` globe button with active tint, "Searching the web…" `ProgressView` indicator above the input bar while the request is in flight
- `MessageBubbleView` shows a collapsible `DisclosureGroup` of sources (title + snippet + date) after the assistant reply when results are present
- Settings screen **Web Search** section: tool name field and max results stepper (1–20, default 10)
- `SettingsManager` extended with `webSearchToolName` / `webSearchMaxResults` keys
- `SettingsViewModel` extended with corresponding state, events, and persistence handlers
- `MockWebSearchUseCase` test double
- `WebSearchUseCaseTests` (5 tests) and `ChatViewModelTests+WebSearch` (6 tests)
- Agent mode (agentic loop) integrated transparently into the chat flow — automatically activated when web search is enabled and the selected model supports function calling (`finish_reason: "tool_calls"` → parallel tool execution → multi-turn loop); falls back to search-context injection for models without `.functionCalling` capability
- `AgentStreamUseCase` (`AgentStreamUseCaseProtocol`) with `AgentEvent` enum — drives the agentic loop (up to 10 iterations) using `withThrowingTaskGroup` for parallel tool execution and streaming the final answer via SSE
- `AgentLoopContext` internal value type grouping the loop's runtime parameters to keep function signatures within SwiftLint limits
- `ChatToolProtocol` — `Sendable` protocol defining a tool executable by the agent (`definition: ToolDefinition` + `execute(arguments:) async throws -> String`)
- `WebSearchTool` — implements `ChatToolProtocol`, executes `WebSearchUseCase` and formats the top results as a Markdown citation list
- `ToolRegistry` — dictionary-based tool registry with `execute(toolName:arguments:)` dispatch and a `static func default(webSearchUseCase:)` factory
- `ToolModels` — `ToolCall`, `ToolCallFunction`, `ToolDefinition`, `ToolFunctionDefinition`, `ToolParameters`, `ToolParameterProperty` Codable structs following the OpenAI tool-calling specification
- `ChatMessage` extended with `.tool` role, `toolCalls: [ToolCall]?`, and `toolCallId: String?` for agent tool-call messages
- `ChatCompletionRequest` extended with `tools: [ToolDefinition]?` and `toolChoice: String?`; `ChatCompletionMessage` extended with `toolCallId` and `toolCalls`; `ChatCompletionResponse.Message` extended with `toolCalls`
- `ChatRepository` extended with `agentCompletion(messages:model:parameters:tools:)` for non-streaming completions with tool definitions
- `ChatViewModel+Agent` extension — `performAgentStreaming` routes to the agentic loop; `applyAgentEvent` maps `AgentEvent` to `LoadedState` mutations
- `MockAgentStreamUseCase` test double and 11 new unit tests across `AgentStreamUseCaseTests` and `ChatViewModelTests+Agent`

## [1.0.0-build-15] - 2026-04-04

### Added

- Export conversations to JSON via share sheet — available from the chat toolbar (context menu in conversation list on macOS, share button in toolbar on iOS/macOS)
- Message editing — long-press any sent user message to edit its content and resend; all subsequent messages are removed and the conversation continues from the edited point
- Response regeneration — "Regenerate Response" button appears above the input bar after every complete assistant reply, allowing the user to request a new response to the same message
- Conversation branching — long-press any message (user or assistant) to fork the conversation from that point; the fork is a fully independent conversation with its own history up to the selected message; branch indicator (`arrow.branch`) shown on forked conversations in the list
- `ExportConversationUseCase` — encodes a `Conversation` to pretty-printed ISO 8601 JSON using `JSONEncoder`
- `BranchConversationUseCase` — forks a conversation at a given message, copying all preceding messages and saving the new conversation via `SaveConversationUseCase`
- `parentConversationId` and `branchedFromMessageId` fields on `Conversation` (optional, backward-compatible)
- `ChatView+ModelSelector.swift` and `ChatView+EditExport.swift` extensions to keep `ChatView.swift` under the 500-line SwiftLint limit
- `ChatViewModel+EditExport.swift` extension grouping all export, regenerate, edit, and branch logic
- `MockExportConversationUseCase` and `MockBranchConversationUseCase` test doubles
- 29 new ViewModel unit tests across `ChatViewModelTests+Export`, `+Regenerate`, `+Editing`, `+Branching`
- 14 new use-case unit tests across `ExportConversationUseCaseTests` and `BranchConversationUseCaseTests`
- Reload button in the chat list toolbar (macOS only), between the New Chat button and the search bar, matching the existing Models reload button design
- Pull-to-refresh in the Models screen (iOS/iPadOS), matching the existing pull-to-refresh in the chat list
- Provider logo images (OpenAI, Anthropic, Ollama, Gemini) shown on each model row in the Models list; models without a recognised logo fall back to a SF Symbol generic icon (`cpu.fill` for local, `sparkles` for cloud)
- `logoImageName` computed property on `LLMModel` mapping `providerName` to asset image names
- `genericLogoSystemName` property on `LLMModel.Provider` for fallback icons
- Poppins custom font family (9 weights) registered in iOS and macOS targets via `UIAppFonts` and `ATSApplicationFontsPath`
- `Font.poppins(_:size:relativeTo:)` extension wrapping `Font.custom(_:size:relativeTo:)` for Dynamic-Type-aware usage
- `PoppinsFont` enum with 9 cases matching font file names
- Poppins applied selectively to key UI elements: onboarding titles and primary action buttons, "How can I help you?" heading in chat empty state, conversation list section headers, model selector label in chat toolbar
- `CFBundleDisplayName = "OpenClient"` in macOS `Info.plist` so the app shows the correct name in Finder, Launchpad, and TestFlight installations
- `.xcodebuildmcp/config.yaml` project configuration for XcodeBuildMCP (simulator + macOS + ui-automation workflows, session defaults, telemetry disabled)
- Scroll-to-top and scroll-to-bottom Liquid Glass buttons in the chat messages view — each button only appears when its direction makes sense (scroll-up hidden when already at the top, scroll-down hidden when already at the bottom or during streaming auto-scroll)
- `"scroll-top"` anchor at the start of the messages `LazyVStack` to enable smooth animated scroll to the first message
- `isNearTop` state tracking in `ChatView` using `onScrollGeometryChange` with an 80 pt threshold
- Dedicated `SearchConversationsView` tab with `searchable(placement: .navigationBarDrawer(displayMode: .always))` — search bar is always visible when the tab is active; shows all conversations when no query is entered, filtered results otherwise
- `Tab(role: .search)` in `HomeView` iOS layout — the system automatically places the search icon at the trailing end of the tab bar, separated from the main tabs (same pattern as Telegram and Apple Music)
- `AppTab` enum (`chats`, `models`, `settings`) to track the selected tab and trigger SF Symbol animations
- SF Symbol animations on tab bar icons on iOS: `.bounce` on Chats (`bubble.left.and.bubble.right`), `.pulse` on Models (`brain.head.profile`), `.rotate` on Settings (`gearshape`) — each animation fires once on selection
- Speech-to-Text (STT) model selection in the Models screen — dedicated section listing STT-capable models; selection persisted via `selectedSTTModelId` in `SettingsManager`
- `selectedSTTModelId` property and related persistence methods added to `SettingsManager` and `SettingsManagerProtocol`
- `ChatViewModel` resolves the selected STT model ID alongside the TTS model ID when routing audio operations
- Regenerate response button shown inline on the last assistant message bubble in `MessageBubbleView`, in addition to the existing toolbar button
- `onForkCreated` callback on `ChatView` propagated through `HomeView` to navigate directly to the new conversation after branching
- Maximum tag limit of 3 enforced in `ConversationTagsView`; add button disabled once the limit is reached
- `Color.appAccent` extension returning `Color("AccentColor")` from the asset catalog — use instead of `Color.accentColor` for consistent branding on macOS regardless of the system accent setting
- `Notification.Name.appDataDidReset` constant centralised in `Core/Extensions/Foundation/Notification.Name.swift`

### Changed

- `WebContentView` macOS header redesigned: title is now centred using `ZStack`, Close button anchored to the trailing edge
- `WebContentView` iOS navigation bar uses `.navigationBarTitleDisplayMode(.inline)` so the title stays fixed alongside the close button rather than disappearing during page load
- `WebDestination.authorGitHub` title changed from the author's name to `"GitHub Profile"` (localized)
- Swipe-to-delete in the conversation list replaced `.onDelete` with `.swipeActions(edge: .trailing, allowsFullSwipe: false)` so the row does not animate away before the user confirms the delete alert
- `ConversationListViewModel.refresh()` now exposes an async `refreshAsync()` variant awaited by `.refreshable` to keep the spinner duration in sync with the actual reload
- `ModelsViewModel.refreshModels()` extracted shared network logic into `performRefresh() async`; `refreshAsync()` awaits it directly so the pull-to-refresh spinner lasts exactly as long as the network call
- Chat messages scroll view gains `.contentMargins(.top, 16, for: .scrollContent)` on macOS to avoid content starting flush against the toolbar
- Keychain queries updated to include `kSecUseDataProtectionKeychain: true` on all operations (get, set, delete) to use the modern Data Protection Keychain on macOS, which never prompts the user for a password
- `.gitignore` updated to exclude `.vscode/` directory
- `TabView` in `HomeView` switched from anonymous tabs to `Tab(value:)` with explicit selection binding to support per-tab symbol animations
- Models tab icon changed from `cpu` to `brain.head.profile` to better reflect AI model selection
- `ConversationListView` search bar removed; search is now handled exclusively by the dedicated search tab, fixing the bug where the search bar would disappear when editing conversation tags
- `ConversationListView` empty-filtered state for tag filter replaced with a dedicated `noTagResults` view (`tag.slash` icon) instead of reusing `ContentUnavailableView.search`
- Conversation tags sorted case-insensitively in `ConversationListViewModel`
- Tag filter bar repositioned above the conversation list rows in `ConversationListView`
- Resend button in the message edit sheet disabled when the edited text is empty
- Chat toolbar buttons apply glass effect and `contentShape` modifier for consistent appearance and hit area
- `ChatView` scrolls to the bottom automatically when a new message arrives
- Reset App Data button in Settings uses `.foregroundStyle(.red)` instead of a tinted button style
- Settings navigation buttons simplified to plain `Label` on macOS — chevron icon and explicit `.buttonStyle(.bordered)` modifiers removed
- Assistant message text blocks rendered using `interpretedSyntax: .inlineOnlyPreservingWhitespace` instead of `.full` — fixes all newlines and paragraph breaks being silently collapsed into spaces or removed, causing every response to appear as a single unformatted block of text regardless of model or provider
- Normalization regex (`\n` → `\n\n`) removed from `textBlockView` as it was redundant and broke adjacent list items with the new rendering option
- Prompt Library — a curated collection of built-in system prompt templates (Coding Assistant, Translator, Summarizer, Creative Writer, Data Analyst, Email Composer) accessible directly from the System Prompt editor in any conversation
- "Browse Library" button in `ChatSystemPromptView` — tapping it opens `PromptTemplatesView` as a sheet; selecting a template fills the system prompt field and closes the sheet automatically
- `PromptTemplatesView` — list with two sections (Built-in / Custom); tap a template to apply it; swipe-to-delete and Edit action on custom templates; toolbar `+` button to create new ones
- `PromptTemplateEditorView` — sheet for creating and editing custom templates with a title field and a full TextEditor for the prompt content; Save button disabled until both fields are non-empty
- `PromptTemplate` model — `Identifiable`, `Equatable`, `Codable`, `Sendable`; `isBuiltIn` flag distinguishes system templates from user-created ones
- `PromptTemplateRepository` — persists custom templates as individual JSON files in `DocumentDirectory/PromptTemplates/`; built-in templates are hardcoded with stable UUIDs and never written to disk
- `LoadPromptTemplatesUseCase`, `SavePromptTemplateUseCase`, `DeletePromptTemplateUseCase` — single-responsibility use cases for the prompt library feature
- `PromptTemplatesViewModel` — Event/State ViewModel coordinating load, save, and delete; built-in templates cannot be deleted (guard in `deleteTemplate`)
- `MockPromptTemplateRepository`, `MockLoadPromptTemplatesUseCase`, `MockSavePromptTemplateUseCase`, `MockDeletePromptTemplateUseCase` test doubles
- 11 unit tests in `PromptTemplatesViewModelTests` covering init state, load success/failure, create, edit (preserving id and createdAt), save failure, delete custom, guard against deleting built-ins, and delete failure

### Fixed

- macOS app name showing as the Xcode target name (`openclient-llm-macOS`) instead of `OpenClient` in Finder and TestFlight installations
- macOS Keychain access prompting for the user's login password on first launch; now uses Data Protection Keychain silently
- Chat responses from all models (cloud and local) appearing as a single unformatted text block with no line breaks — root cause was `AttributedString(markdown:options:)` with `.full` syntax discarding all newline characters from the character string

## [0.0.1-build-11] - 2026-04-02

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