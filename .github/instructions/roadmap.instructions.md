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
- [x] **User profile (personal context)**: In Settings, allow the user to configure a display name (how models should address them), a personal description, and extra freeform context. Presented as a modal sheet with three text fields: Name (max 50 chars), Description (max 200 chars), Extra info (max 500 chars). Data saved to iCloud key-value store (`NSUbiquitousKeyValueStore`) when iCloud is available, falling back to `UserDefaults` when not. The stored values are injected into every system prompt so models can personalise their responses. Scroll in the modal dismisses the keyboard (`.scrollDismissesKeyboard(.interactively)`); the form uses `.ignoresSafeArea(.keyboard, edges: .bottom)` with keyboard-aware padding so no TextField is ever obscured.
- [x] **iPadOS layout redesign**: Full review and fix of the iPadOS UI — layouts, navigation, split view, and all interactions — so the app works flawlessly on iPad
- [ ] **macOS layout redesign**: Full review and fix of the macOS UI — sidebar, toolbar, window sizing, keyboard navigation, and all platform-specific interactions — so the app works flawlessly on Mac

## Phase 6 — Advanced Interactions

Goal: Web search, agentic capabilities, and enhanced chat workflows.

- [ ] **Export**: Export conversations to JSON
- [ ] **Web browsing**: Enable models to search and retrieve web content via LiteLLM's `/v1/search` endpoint (provider-agnostic: Brave, Tavily, Perplexity, etc. configured on the server). Two modes: (A) globe button in chat input bar for manual search on any model — app calls `/v1/search/{tool_name}`, injects results as context, then calls `/chat/completions`; (B) automatic interception for models with function calling — app includes `litellm_web_search` tool in every request and LiteLLM resolves the loop transparently. Settings: search tool name (default `brave-search`), interception toggle. No search API key in the app. See web-browsing.instructions.md.
- [ ] **Agent mode (tool calling)**: Support LiteLLM function/tool calling loop — parse tool_calls from model responses, execute registered tools, send results back, and repeat until final answer
- [ ] **Conversation branching**: Fork a conversation from any message to explore alternative responses (edit & resend)
- [ ] **Prompt templates/library**: Library of predefined system prompts (coding assistant, translator, summarizer...) that users can save and reuse
- [ ] **Message editing**: Edit an already sent user message and regenerate the assistant response
- [ ] **Response regeneration**: "Regenerate" button to request a new response to the last message

## Phase 7 — Voice & TTS Enhancements

Goal: Richer audio experience with voice selection per TTS model.

- [ ] **Voice selector for TTS models**: In the Models screen, TTS models (identified by `mode == "audio_speech"` from `/model/info`) show a voice picker. Displays the 6 canonical OpenAI voices (`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`) as preset options plus a free-text field for custom voice IDs (ElevenLabs IDs, AWS Polly names, etc.). Selected voice saved in `SettingsManager` (UserDefaults) keyed by model name. Voice sent as the `voice` field in every `POST /v1/audio/speech` request. Note: LiteLLM does not expose a `supported_voices` field in `/model/info` — the canonical OpenAI voices are used as sensible defaults since LiteLLM maps them automatically across most providers (ElevenLabs, Gemini, Vertex AI, etc.).

## Current Phase: 6 — Advanced Interactions

Focus exclusively on Phase 6 features. Do not over-engineer for future phases.