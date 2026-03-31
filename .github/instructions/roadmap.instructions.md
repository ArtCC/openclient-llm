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

## Phase 4 — Advanced Features

Goal: Power user features.

- [ ] **Token usage display**: Show token count per message/conversation
- [ ] **Model parameters**: Temperature, max tokens, top_p per conversation
- [ ] **Search conversations**: Full-text search across conversations
- [ ] **Export**: Export conversations to JSON/Markdown
- [ ] **iCloud sync**: Sync conversations across devices
- [ ] **Image generation**: Generate images from text prompts via POST /v1/images/generations (DALL-E, Stable Diffusion, Gemini, etc.)
- [ ] **Audio transcription (Speech-to-Text)**: Record or upload audio for transcription via POST /v1/audio/transcriptions (Whisper, Groq, Deepgram, Gemini)
- [ ] **Text-to-Speech**: Read assistant responses aloud via POST /v1/audio/speech (OpenAI TTS, AWS Polly, ElevenLabs, Gemini TTS)

## Phase 5 — Infrastructure, Multi-Server & Others

Goal: Support for multiple server configurations and infrastructure improvements.

- [ ] **Multiple servers**: Support multiple LiteLLM server configurations

## Current Phase: 4 — Advanced Features

Focus exclusively on Phase 4 features. Do not over-engineer for future phases.