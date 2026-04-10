---
description: "Use when planning features, prioritizing work, defining scope, or deciding what to implement next in the project roadmap."
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

- [ ] **Chat toolbar menu consolidation**: Replace the three individual action buttons on the right side of the chat header (`square.and.arrow.up`, `slider.horizontal.3`, `text.bubble`) with a single `Menu` button (`ellipsis.circle`). Menu options listed in alphabetical order: Export (ShareLink), Favourites, Media & Files, Model Parameters, System Prompt. "Media & Files" is only shown when the conversation has at least one attachment. Applies to both iOS and macOS. On macOS, use the native SwiftUI `Menu` behaviour; if a custom view is needed to match platform conventions it will be implemented as a dedicated component.
- [ ] **Favourite messages**: Long-pressing any message shows a context menu option to mark/unmark it as a favourite (`isFavorite: Bool` field added to `ChatMessage`, persisted via the existing `Codable` + `FileManager` layer). The "Favourites" entry in the chat toolbar menu opens a sheet listing all favourited messages in the current conversation. Each row shows the message role, a text preview, and the date. Tapping a row dismisses the sheet and scrolls directly to that message in the chat using the existing `ScrollViewReader` + `proxy.scrollTo(message.id, anchor: .center)` infrastructure.
- [ ] **macOS menu bar companion**: A persistent `NSStatusItem` in the macOS menu bar that opens a compact popover with a full quick-chat interface. Features: text input, streaming response display using the currently active model and server configuration, and an "Open in app" button to continue the conversation in the main window. The companion works whether the main app window is open or closed. State (active model, API key, base URL) is shared with the main app via the existing managers.
- [ ] **Media & Files gallery**: The "Media & Files" entry in the chat toolbar menu opens a sheet with two sections — images displayed in a `LazyVGrid` of square thumbnails (rendered directly from the persisted `Data`, no network required), and documents listed by `fileName` and date. Tapping an image opens the existing `ImagePreviewView`. Tapping a document opens a `QuickLook` / `PDFView` sheet. Both support a "Go to message" action that dismisses the sheet and scrolls to the originating message using `proxy.scrollTo(message.id, anchor: .center)`.

## Phase 10 — System Integration & Import

Goal: Allow other apps to send content to OpenClient LLM and let users bring data from external sources.

- [ ] **Share Extension (iOS/iPadOS/macOS)**: System extension to receive text, URLs, images, and PDFs shared from any app (Safari, Notes, Files…). When activated, opens OpenClient and creates a new conversation with the shared content as an attachment or initial message.
- [ ] **Drag & Drop between apps**: Accept drags from other apps directly into the chat input — text, images, files — especially useful on iPad and macOS where multitasking with Split View is common.
- [ ] **Custom URL scheme (`openclient://`)**: URL scheme to open the app with prefilled content from external automations, Shortcuts, or third-party apps.
- [ ] **Apple Shortcuts integration**: Define `AppIntents`/`NSUserActivity` so Shortcuts can execute actions such as "New conversation with message", "Search conversations", or "Send file to chat".
- [ ] **Widget (iOS/iPadOS)**: Home Screen / Lock Screen widget using WidgetKit. Exact widget types, sizes, and content to be defined — needs further scoping before implementation.
- [ ] **Live Activities / Dynamic Island (iOS)**: Show the streaming of an in-progress response on the Lock Screen and in the Dynamic Island while the user multitasks. Implemented via `ActivityKit` with a `ActivityAttributes` struct carrying the current partial response text and model name.

## Current Phase: 9 — UI Polish & macOS Companion

Focus exclusively on Phase 9 features. Do not over-engineer for future phases.