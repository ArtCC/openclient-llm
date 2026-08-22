---
description: "Use when reviewing completed features or checking what has already been implemented in the project roadmap."
---

# Feature Roadmap

## Development Approach

Build incrementally from less to more. Each phase should result in a functional app.

## Phase 1 — Foundation

Goal: Basic chat with a LiteLLM server.

- [x] **Server configuration**: Settings screen to input base URL and optional API key
- [x] **Connection test**: Health check to validate server is reachable
- [x] **Model listing**: Fetch and display available models from LiteLLM
- [x] **Basic chat**: Send a message, receive a response (non-streaming)
- [x] **Streaming chat**: SSE streaming for real-time token display
- [x] **Conversation view**: Chat bubble UI with user/assistant messages
- [x] **UI redesign**: ChatGPT-inspired conversational interface (glass messages, pill input bar, suggestion chips, model selector, streaming cursor, markdown rendering)
- [x] **Model capabilities**: Display model capabilities as colored tags (vision, tools, function calling, JSON mode, etc.) fetched from `GET /model/info` endpoint
- [x] **Model selection from list**: Tap a model in the models screen to select it as active; selected model highlighted with blue accent border; change reflected instantly in the chat scene model selector
- [x] **Settings support section**: Settings provides Buy Me a Coffee, Rate the App, Suggest Features, and Help actions. Suggest Features presents `Votice.feedbackView()`; Votice is configured at launch from bundle values supplied by `Secrets.xcconfig`, with localized text, comments, status filters, Liquid Glass, and SDK debug logging disabled. `VoticeManager` currently sets premium status to `false` regardless of the `userIsPremium` argument.
- [x] **About author**: In the About section of Settings, show author name (Arturo Carretero Calvo) with a link to the GitHub profile (https://github.com/ArtCC) that opens in a modal WebView

## Phase 2 — Usability

Goal: Daily-usable chat experience.

- [x] **Conversation persistence**: Save/load conversations locally (Codable + FileManager)
- [x] **Conversation list**: Sidebar/list of past conversations
- [x] **New conversation**: Create new chats, select model per conversation
- [x] **System prompt**: Configurable system prompt per conversation
- [x] **Copy/share messages**: Copy individual messages, share conversations
- [x] **Markdown rendering**: Render assistant responses with full Markdown + code blocks (basic inline markdown already implemented)
- [x] **Vision (images in chat)**: Attach photos from camera/gallery for the LLM to analyze (same /chat/completions endpoint with image_url content)
- [x] **Document understanding (PDFs in chat)**: Upload PDFs and ask questions about their content (same /chat/completions endpoint with file content)

## Phase 3 — Multi-Platform Polish

Goal: Platform-optimized experience.

- [x] **macOS sidebar**: NavigationSplitView with conversation list
- [x] **iPadOS split view**: Adaptive layout for iPad
- [x] **Keyboard shortcuts**: macOS keyboard navigation
- [x] **Menu bar**: macOS menu items for common actions
- [x] **Dark/Light mode**: Full theme support with semantic colors
- [x] **Debug logging system**: LogManager with emoji-differentiated log levels (info, debug, warning, error, network) for readable console output in DEBUG builds
- [x] **Attachment thumbnails in chat**: Show image thumbnails inline in sent messages (small rounded preview); show document attachments as icon + filename card
- [x] **Camera image capture**: Attach images directly from the device camera in chat (iOS/iPadOS only)

## Phase 4 — Advanced Features

Goal: Power user features.

- [x] **Token usage display**: Show token count per message/conversation
- [x] **Model parameters**: Temperature, max tokens, top_p per conversation
- [x] **Search conversations**: Full-text search across conversations
- [x] **iCloud sync**: Sync conversations across devices through iCloud Drive with one JSON file per conversation, attachment folders, safe first-time reconciliation, remote-change observation, offline deletion tombstones, and manual sync status in Settings; sync is private to devices signed into the same Apple ID
- [x] **Generated images in chat**: Display images returned by compatible chat models and support dedicated image-generation models through `/v1/images/generations`.
- [x] **Audio transcription (Speech-to-Text)**: Dictate messages in chat via microphone; audio transcribed via POST /v1/audio/transcriptions (Whisper, Groq, Deepgram, Gemini) and inserted into the chat input field
- [x] **Text-to-Speech**: Read assistant responses aloud via POST /v1/audio/speech (OpenAI TTS, AWS Polly, ElevenLabs, Gemini TTS)

## Phase 5 — Personalization

Goal: User customization.

- [x] **Pinned conversations**: Pin important conversations to the top of the list
- [x] **Conversation folders/tags**: Organize chats into folders or with tags
- [x] **User profile (personal context)**: Settings lets the user configure a display name, personal description, and extra context, which are injected into the effective system prompt. `UserProfileManager` stores `UserProfile.json` locally in Documents and, when iCloud sync is enabled, uses the iCloud Documents copy as the source of truth while maintaining the local cache. It migrates the former UserDefaults blob and legacy per-key UserDefaults/`NSUbiquitousKeyValueStore` values.
- [x] **iPadOS layout redesign**: Full review and fix of the iPadOS UI — layouts, navigation, split view, and all interactions — so the app works flawlessly on iPad
- [x] **macOS layout redesign**: Full review and fix of the macOS UI — sidebar, toolbar, window sizing, keyboard navigation, and all platform-specific interactions — so the app works flawlessly on Mac
- [x] **Voice selector for TTS models**: In the Models screen, TTS models (identified by `mode == "audio_speech"` from `/model/info`) show a voice picker. Displays the 6 canonical OpenAI voices (`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`) as preset options plus a free-text field for custom voice IDs (ElevenLabs IDs, AWS Polly names, etc.). Selected voice saved in `SettingsManager` (UserDefaults) keyed by model name. Voice sent as the `voice` field in every `POST /v1/audio/speech` request. Note: LiteLLM does not expose a `supported_voices` field in `/model/info` — the canonical OpenAI voices are used as sensible defaults since LiteLLM maps them automatically across most providers (ElevenLabs, Gemini, Vertex AI, etc.).

## Phase 6 — Productivity & Editing

Goal: Conversation editing, content management, and productivity tools.

- [x] **Export**: Export conversations to JSON
- [x] **Conversation branching**: Fork a conversation from any message to explore alternative responses (edit & resend)
- [x] **Message editing**: Edit an already sent user message and regenerate the assistant response
- [x] **Response regeneration**: "Regenerate" button to request a new response to the last message

## Phase 7 — Web, Agents & Prompt Library

Goal: Prompt templates, web search, and agentic tool-calling loop.

- [x] **Thinking / Reasoning disclosure**: Collapsible "Thinking…" block shown above the assistant reply for models that return reasoning content. LiteLLM ≥ v1.63.0 exposes a standardised `reasoning_content` field in `message` (and `delta.reasoning_content` in SSE chunks) for all supported reasoning providers (Anthropic, Deepseek, OpenAI Responses API, Gemini, Groq, Mistral, Perplexity, OpenRouter, XAI, Bedrock). Implementation: (A) extend `StreamChunk` with a `.reasoning(String)` case; (B) parse `delta.reasoning_content` in the SSE decoder and emit reasoning chunks separately from normal token chunks; (C) add a `reasoningContent: String?` field to `ChatMessage`; (D) in `MessageBubbleView`, show a tappable `DisclosureGroup` styled pill ("Thinking · chevron") that streams the reasoning text live — animated pulsing while still receiving chunks, static when complete; disclosure view has a fixed max height with internal scroll so it never dominates the screen; reasoning text styled in a dimmer secondary color with monospace font; the pill collapses by default after streaming finishes; (E) no setting required — the widget appears automatically when `reasoningContent` is non-nil.
- [x] **Prompt templates/library**: Library of predefined system prompts (coding assistant, translator, summarizer...) that users can save and reuse
- [x] **Web browsing**: Function-calling models can invoke `web_search` in the agent loop; `WebSearchTool` delegates to the user's LiteLLM proxy through `POST /v1/search/{search_tool_name}` and returns source metadata to the chat UI. Search providers and their credentials remain server-side. Web search defaults off, the search tool name defaults to an empty string, Settings discovers configured tools through `GET /v1/search/tools`, and the globe cannot enable search until a tool is configured. See `web-browsing.instructions.md`.
- [x] **Agent mode (tool calling)**: Support LiteLLM function/tool calling loop — parse tool_calls from model responses, execute registered tools, send results back, and repeat until final answer
- [x] **MCP tools support**: Discover, list, enable, and execute tools from Model Context Protocol servers configured on the LiteLLM backend. `MCPTool` conforms to `ChatToolProtocol` and is automatically added to the agent tool registry. Users manage tools through a dedicated MCP Tools sheet accessible from the chat input bar or Settings.

## Phase 8 — System Integration & Shortcuts

Goal: Deeper OS integration and quick actions.

- [x] **App icon quick actions (iOS/iPadOS)**: Add Home Screen quick actions to the iOS and iPadOS app icon using `UIApplicationShortcutItem`. Actions: "New Chat" (creates a blank conversation and navigates directly to chat input) and "Search" (opens the conversation list with the search field already focused). Actions defined statically in `Info.plist` and/or dynamically at runtime via `UIApplication.shortcutItems`. Handled in the app delegate / scene delegate with a `ShortcutAction` enum (`newChat`, `search`) routed through the navigation state.
- [x] **Spotlight search**: Index conversations with `CSSearchableItem` / `CoreSpotlight` so users can find past chats directly from Spotlight. Each conversation is indexed with its title and a snippet of the last message. Tapping a Spotlight result opens the app directly in that conversation via `NSUserActivity` continuation.

## Phase 9 — UI Polish & macOS Companion

Goal: Clean up the chat header, reduce toolbar clutter, and bring a quick-access companion to macOS.

- [x] **Chat toolbar menu consolidation**: Replace the three individual action buttons on the right side of the chat header (`square.and.arrow.up`, `slider.horizontal.3`, `text.bubble`) with a single `Menu` button (`ellipsis.circle`). Menu options listed in alphabetical order: Export (ShareLink), Favourites, Media & Files, Model Parameters, System Prompt. "Media & Files" is only shown when the conversation has at least one attachment. Applies to both iOS and macOS. On macOS, use the native SwiftUI `Menu` behaviour; if a custom view is needed to match platform conventions it will be implemented as a dedicated component.
- [x] **Favourite messages**: Long-pressing any message shows a context menu option to toggle its `isFavourite` value, persisted with the conversation through the existing `Codable` + `FileManager` layer. The "Favourites" entry in the chat toolbar menu opens a sheet listing all favourited messages in the current conversation. Each row shows the message role, a text preview, and the date. Tapping a row dismisses the sheet and requests a scroll to that message through the chat's programmatic scroll state.
- [x] **macOS menu bar companion**: A persistent `NSStatusItem` in the macOS menu bar that opens a compact popover with a full quick-chat interface. Features: text input, streaming response display using the currently active model and server configuration, and an "Open in app" button to continue the conversation in the main window. The companion works whether the main app window is open or closed. State (active model, API key, base URL) is shared with the main app via the existing managers.
- [x] **Media & Files gallery**: The "Media & Files" entry in the chat toolbar menu opens a sheet with image thumbnails and a document list. Attachment metadata remains in the conversation while binary data is loaded on demand from `AttachmentRepository`; no network request is required. Tapping an image opens `ImagePreviewView`, and tapping a PDF opens the platform preview. "Go to message" dismisses the sheet and requests a scroll to the originating message through the chat's programmatic scroll state.

## Phase 10 — Memory

Goal: Give users and models a persistent, editable memory layer that is always injected into the system prompt.

- [x] **User memory list**: Settings shows memory items with enabled state, source, and creation date; users can add, edit, delete, and toggle them, and enabled items are injected as a `## Memory` block. `MemoryManager` stores `Memory.json` locally in Documents and mirrors it to iCloud Documents when sync is enabled, using the cloud copy as source of truth and maintaining a local cache. It migrates the legacy `memory_items` UserDefaults blob.
- [x] **Model memory tool**: Register a `save_memory(content: String)` tool in the existing agentic loop (Phase 7). When the model calls it, a new `MemoryItem` with `source: .model` is created and saved to the same store as user memory. The item appears immediately in the Memory list in Settings, where the user can review, edit, disable, or delete it.

## Phase 11 — Model Detail & Cost Intelligence

Goal: Surface per-model metadata and give users visibility into conversation cost.

- [x] **Model detail view**: Each model row in the Models screen gets a new info button (`ⓘ`) that opens a detail sheet without affecting the existing tap-to-select gesture. The `ⓘ` button is shown for all models. No additional network request is needed: `GET /model/info` is already called during model list fetch; the missing step is persisting `maxInputTokens`, `maxOutputTokens`, `inputCostPerToken`, and `outputCostPerToken` into `LLMModel` (they are currently discarded in `FetchModelsUseCase`). The detail sheet renders only rows with real data (non-nil, non-zero): context window, pricing, provider, mode, and capability badges. Rows with no data are simply omitted — no empty or zero-value fields shown.
- [x] **Estimated conversation cost**: Running cost total displayed in the model parameters sheet, calculated from stored per-message token counts × `inputCostPerToken` / `outputCostPerToken` from the active model. Shown as a formatted currency string (e.g. `~$0.0042`). Hidden entirely when pricing data is unavailable (nil or zero — local/Ollama models).

## Phase 12 — System Integration & Import

Goal: Allow other apps to send content to OpenClient and let users bring data from external sources.

- [x] **Share Extension (iOS/iPadOS)**: System extension to receive text, URLs, images, and PDFs shared from any app (Safari, Notes, Files…). When activated, opens OpenClient and creates a new conversation with the shared content as an attachment or initial message.
- [x] **Custom URL scheme (`openclient://`)**: URL scheme to open the app with prefilled content from external automations, Shortcuts, or third-party apps.
- [x] **Drag & Drop between apps**: Accept drags from other apps directly into the chat input — text, images, files — especially useful on iPad and macOS where multitasking with Split View is common.
- [x] **Apple Shortcuts integration**: Define `AppIntents`/`NSUserActivity` so Shortcuts can execute actions such as "New conversation with message", "Search conversations", or "Send file to chat".

## Phase 13 — Apple Platform Extensions

Goal: Extend the app across Apple platforms and system surfaces with widgets and quick-access controls.

- [x] **New Chat system control (iOS/iPadOS/macOS)**: `NewChatControlWidget` uses the shared `NewChatControlIntent`, which writes a one-time request through `WidgetControlStore` in the App Group. The iOS and macOS lifecycle delegates consume the request after activation and route it through `ShortcutManager`.
- [x] **Widgets (WidgetKit)**: `WidgetsExtension-iOS` and `WidgetsExtension-macOS` compile the same seven widgets, control, providers, intents, models, and resources from `WidgetsShared`. Widgets use `openclient://` deep links. Lightweight snapshots (`id`, title, model ID, last-message preview, update date, pinned state, and tags) are stored in App Group `UserDefaults` under `group.com.artcc.openclient-llm`; full conversations, credentials, server URLs, and settings are not shared. The apps rebuild recent, pinned, and tagged snapshots after conversation changes and selectively reload the affected timelines. Widgets:
  - **New Chat (Small)**: `StaticConfiguration` with a single timeline entry. Shows the app icon and "New Chat" label. Tap opens the app in a blank conversation via `widgetURL(URL(string: "openclient://new-chat"))`.
  - **Search (Small)**: `StaticConfiguration` with a single timeline entry. Opens the Search destination through `openclient://search` on iOS, iPadOS, and macOS.
  - **Quick Actions (Medium)**: `StaticConfiguration` with vertically stacked New Chat and Search link rows, each showing an icon, label, subtitle, and chevron. Uses the same deep links as the Small widgets.
  - **Conversations Overview (Medium/Large)**: `TimelineProvider` showing up to two recent conversations in medium size or five in large size, with title, preview, model styling, timestamp, Search, and New Chat links.
  - **Continue Chat (Medium)**: Shows the latest conversation and opens it directly through its conversation deep link.
  - **Pinned Conversations (Medium/Large)**: Shows up to two or five pinned conversations from the dedicated pinned snapshot.
  - **Tagged Conversations (Medium/Large)**: `AppIntentConfiguration` lets the user choose a tag and shows matching conversation snapshots.

## Phase 14 — Contextual Feature Discovery

Goal: Help users discover advanced features at the moment they become relevant without extending the initial onboarding.

- [x] **Native TipKit integration**: Configure TipKit once per iOS, iPadOS, and macOS app session with a daily global display frequency and native popover presentation.
- [x] **Chat feature tips**: Contextual popovers explain model selection, attachments, message actions, web search, conversation options, and context usage only while their related controls and capabilities are available.
- [x] **Organization and privacy tips**: The conversation list introduces Private Chat after a normal conversation exists and organization controls after five conversations.
- [x] **Memory tip**: Settings introduces editable memory after the user has accumulated at least three conversations.
- [x] **Informational-only content**: Tips contain only localized titles and messages, with no actions or custom navigation inside the popover; using the highlighted feature invalidates its tip.
- [x] **Tip reset and testing**: Help can make invalidated tips eligible again, while the `-showAllFeatureTips` DEBUG launch argument uses TipKit's testing override for visual verification.
