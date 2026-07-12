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
- [x] **Settings feedback section**: New section above About in Settings with two buttons — "Rate the App" (opens App Store review URL directly) and "Suggest Features" (placeholder print for now; will integrate Votice SDK in the future for feature suggestions and bug reports)
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
- [x] **iCloud sync**: Sync conversations across devices
- [x] **Image generation**: Generate images from text prompts via POST /v1/images/generations (DALL-E, Stable Diffusion, Gemini, etc.)
- [x] **Audio transcription (Speech-to-Text)**: Dictate messages in chat via microphone; audio transcribed via POST /v1/audio/transcriptions (Whisper, Groq, Deepgram, Gemini) and inserted into the chat input field
- [x] **Text-to-Speech**: Read assistant responses aloud via POST /v1/audio/speech (OpenAI TTS, AWS Polly, ElevenLabs, Gemini TTS)

## Phase 5 — Personalization

Goal: User customization.

- [x] **Pinned conversations**: Pin important conversations to the top of the list
- [x] **Conversation folders/tags**: Organize chats into folders or with tags
- [x] **User profile (personal context)**: In Settings, allow the user to configure a display name (how models should address them), a personal description, and extra freeform context. Presented as a modal sheet with three text fields: Name (max 50 chars), Description (max 500 chars), Extra info (max 500 chars). Data saved to iCloud key-value store (`NSUbiquitousKeyValueStore`) when iCloud is available, falling back to `UserDefaults` when not. The stored values are injected into every system prompt so models can personalise their responses. Scroll in the modal dismisses the keyboard (`.scrollDismissesKeyboard(.interactively)`); the form relies on native SwiftUI keyboard avoidance so no TextField is ever obscured.
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
- [x] **Web browsing**: Enable models to search and retrieve web content using **exclusively** the LiteLLM Search API (≥ v1.78.7). The app never calls any search provider directly — it delegates all search to the user's LiteLLM proxy via `POST /v1/search/{search_tool_name}`. Flow: (1) user taps the globe button in the chat input bar; (2) app calls `/v1/search/{search_tool_name}` with the user query; (3) results are injected as context into the next `/chat/completions` request; (4) model responds with inline citations. Provider-agnostic: Brave, Tavily, Perplexity, Exa AI, DuckDuckGo, SearXNG, etc. are all configured server-side — no API key lives in the app. Settings: search tool name (default `"brave-search"`, must match `search_tool_name` in the server's `config.yaml`). Requires LiteLLM ≥ v1.78.7. See web-browsing.instructions.md.
- [x] **Agent mode (tool calling)**: Support LiteLLM function/tool calling loop — parse tool_calls from model responses, execute registered tools, send results back, and repeat until final answer

## Phase 8 — System Integration & Shortcuts

Goal: Deeper OS integration and quick actions.

- [x] **App icon quick actions (iOS/iPadOS)**: Add Home Screen quick actions to the iOS and iPadOS app icon using `UIApplicationShortcutItem`. Actions: "New Chat" (creates a blank conversation and navigates directly to chat input) and "Search" (opens the conversation list with the search field already focused). Actions defined statically in `Info.plist` and/or dynamically at runtime via `UIApplication.shortcutItems`. Handled in the app delegate / scene delegate with a `ShortcutAction` enum (`newChat`, `search`) routed through the navigation state.
- [x] **Spotlight search**: Index conversations with `CSSearchableItem` / `CoreSpotlight` so users can find past chats directly from Spotlight. Each conversation is indexed with its title and a snippet of the last message. Tapping a Spotlight result opens the app directly in that conversation via `NSUserActivity` continuation.

## Phase 9 — UI Polish & macOS Companion

Goal: Clean up the chat header, reduce toolbar clutter, and bring a quick-access companion to macOS.

- [x] **Chat toolbar menu consolidation**: Replace the three individual action buttons on the right side of the chat header (`square.and.arrow.up`, `slider.horizontal.3`, `text.bubble`) with a single `Menu` button (`ellipsis.circle`). Menu options listed in alphabetical order: Export (ShareLink), Favourites, Media & Files, Model Parameters, System Prompt. "Media & Files" is only shown when the conversation has at least one attachment. Applies to both iOS and macOS. On macOS, use the native SwiftUI `Menu` behaviour; if a custom view is needed to match platform conventions it will be implemented as a dedicated component.
- [x] **Favourite messages**: Long-pressing any message shows a context menu option to mark/unmark it as a favourite (`isFavorite: Bool` field added to `ChatMessage`, persisted via the existing `Codable` + `FileManager` layer). The "Favourites" entry in the chat toolbar menu opens a sheet listing all favourited messages in the current conversation. Each row shows the message role, a text preview, and the date. Tapping a row dismisses the sheet and scrolls directly to that message in the chat using the existing `ScrollViewReader` + `proxy.scrollTo(message.id, anchor: .center)` infrastructure.
- [x] **macOS menu bar companion**: A persistent `NSStatusItem` in the macOS menu bar that opens a compact popover with a full quick-chat interface. Features: text input, streaming response display using the currently active model and server configuration, and an "Open in app" button to continue the conversation in the main window. The companion works whether the main app window is open or closed. State (active model, API key, base URL) is shared with the main app via the existing managers.
- [x] **Media & Files gallery**: The "Media & Files" entry in the chat toolbar menu opens a sheet with two sections — images displayed in a `LazyVGrid` of square thumbnails (rendered directly from the persisted `Data`, no network required), and documents listed by `fileName` and date. Tapping an image opens the existing `ImagePreviewView`. Tapping a document opens a `QuickLook` / `PDFView` sheet. Both support a "Go to message" action that dismisses the sheet and scrolls to the originating message using `proxy.scrollTo(message.id, anchor: .center)`.

## Phase 10 — Memory

Goal: Give users and models a persistent, editable memory layer that is always injected into the system prompt.

- [x] **User memory list**: New "Memory" section in Settings showing a list of memory items. Each item has content text, an enabled/disabled toggle, a source badge (user vs. model), and creation date. Users can add, edit, delete, and toggle any item. All items with `isEnabled == true` are injected into every system prompt as a `## Memory` block, alongside the existing user profile context. Storage: `NSUbiquitousKeyValueStore` (synced across devices when iCloud is enabled), falling back to `UserDefaults` when not. Data model: `MemoryItem` (id, content, isEnabled, createdAt, source: `.user` | `.model`), Codable + Sendable.
- [x] **Model memory tool**: Register a `save_memory(content: String)` tool in the existing agentic loop (Phase 7). When the model calls it, a new `MemoryItem` with `source: .model` is created and saved to the same store as user memory. The item appears immediately in the Memory list in Settings, where the user can review, edit, disable, or delete it.

## Phase 11 — Model Detail & Cost Intelligence

Goal: Surface per-model metadata and give users visibility into conversation cost.

- [x] **Model detail view**: Each model row in the Models screen gets a new info button (`ⓘ`) that opens a detail sheet without affecting the existing tap-to-select gesture. The `ⓘ` button is shown for all models. No additional network request is needed: `GET /model/info` is already called during model list fetch; the missing step is persisting `maxInputTokens`, `maxOutputTokens`, `inputCostPerToken`, and `outputCostPerToken` into `LLMModel` (they are currently discarded in `FetchModelsUseCase`). The detail sheet renders only rows with real data (non-nil, non-zero): context window, pricing, provider, mode, and capability badges. Rows with no data are simply omitted — no empty or zero-value fields shown.
- [x] **Estimated conversation cost**: Running cost total displayed in the model parameters sheet, calculated from stored per-message token counts × `inputCostPerToken` / `outputCostPerToken` from the active model. Shown as a formatted currency string (e.g. `~$0.0042`). Hidden entirely when pricing data is unavailable (nil or zero — local/Ollama models).

## Phase 12 — System Integration & Import

Goal: Allow other apps to send content to OpenClient LLM and let users bring data from external sources.

- [x] **Share Extension (iOS/iPadOS)**: System extension to receive text, URLs, images, and PDFs shared from any app (Safari, Notes, Files…). When activated, opens OpenClient and creates a new conversation with the shared content as an attachment or initial message.
- [x] **Custom URL scheme (`openclient://`)**: URL scheme to open the app with prefilled content from external automations, Shortcuts, or third-party apps.
- [x] **Drag & Drop between apps**: Accept drags from other apps directly into the chat input — text, images, files — especially useful on iPad and macOS where multitasking with Split View is common.
- [x] **Apple Shortcuts integration**: Define `AppIntents`/`NSUserActivity` so Shortcuts can execute actions such as "New conversation with message", "Search conversations", or "Send file to chat".

## Phase 13 — Apple Platform Extensions

Goal: Extend the app across Apple platforms and system surfaces — widgets, watch, notifications, and quick-access controls.

- [x] **Control Center toggle (iOS 18+)**: A `ControlWidget` (WidgetKit) that adds a "New Chat" button to the iOS Control Center. Defined as a `ControlWidgetButton` with a `bubble.left.fill` SF Symbol icon and a label. The action is an `AppIntent` (reuses the existing intents from Phase 12 Apple Shortcuts integration) that opens the app in a blank conversation via `openclient://new-chat`. Lives inside the same `OpenClientWidgets` extension target used by the WidgetKit widgets — no additional target needed. The user adds it manually to their Control Center layout (iOS 18+ drag-and-drop customization). Provides the fastest possible access to a new chat: one swipe from any screen or the lock screen + one tap.
- [x] **Widgets (WidgetKit)**: New `OpenClientWidgets` extension target with a `WidgetBundle` exposing four widgets. All widgets share data via an **App Group** (`group.com.artcc.openclient-llm`): conversations, pinned state, settings, and server URL are read from `UserDefaults(suiteName:)` and the shared `FileManager` container. The app writes to the App Group container on every data change and calls `WidgetCenter.shared.reloadAllTimelines()` to keep widgets fresh. Deep links use the existing `openclient://` URL scheme. Widgets:
  - **New Chat (Small)**: `StaticConfiguration` with a single timeline entry. Shows the app icon and "New Chat" label. Tap opens the app in a blank conversation via `widgetURL(URL(string: "openclient://new-chat"))`.
  - **Search (Small)**: `StaticConfiguration` with a single timeline entry. Shows a magnifying glass icon and "Search" label. Tap opens the app directly in the Search tab with the keyboard focused via `widgetURL(URL(string: "openclient://search"))`. Requires adding `case search` to `URLSchemeAction` and handling it in `URLSchemeParser` and `URLSchemeManager`.
  - **Quick Actions (Medium)**: `StaticConfiguration` with two `Link` buttons side by side in an `HStack` — "New Chat" (`bubble.left.and.bubble.right`) and "Search" (`magnifyingglass`). Each button has a large icon and a label below. Uses the same deep links as the Small widgets.
  - **Conversations Overview (Large)**: `TimelineProvider` with 4–5 recent conversations. Header row with "Recent" title and a "New Chat" `Link` button. Each conversation row shows title, last message preview (truncated), and model name. Rows and button use deep links. Implementation order: (1) App Group infrastructure + shared data provider, (2) New Chat + Search + Quick Actions, (3) Overview.