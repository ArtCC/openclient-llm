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

## Phase 2 — Usability

Goal: Daily-usable chat experience.

- [ ] **Conversation persistence**: Save/load conversations locally (Codable + FileManager)
- [ ] **Conversation list**: Sidebar/list of past conversations
- [ ] **New conversation**: Create new chats, select model per conversation
- [ ] **System prompt**: Configurable system prompt per conversation
- [ ] **Copy/share messages**: Copy individual messages, share conversations
- [ ] **Markdown rendering**: Render assistant responses with full Markdown + code blocks (basic inline markdown already implemented)
- [ ] **Vision (images in chat)**: Attach photos from camera/gallery for the LLM to analyze (same /chat/completions endpoint with image_url content)
- [ ] **Document understanding (PDFs in chat)**: Upload PDFs and ask questions about their content (same /chat/completions endpoint with file content)

## Phase 3 — Multi-Platform Polish

Goal: Platform-optimized experience.

- [ ] **macOS sidebar**: NavigationSplitView with conversation list
- [ ] **iPadOS split view**: Adaptive layout for iPad
- [ ] **Keyboard shortcuts**: macOS keyboard navigation
- [ ] **Menu bar**: macOS menu items for common actions
- [ ] **Dark/Light mode**: Full theme support with semantic colors

## Phase 4 — Advanced Features

Goal: Power user features.

- [ ] **Multiple servers**: Support multiple LiteLLM server configurations
- [ ] **Token usage display**: Show token count per message/conversation
- [ ] **Model parameters**: Temperature, max tokens, top_p per conversation
- [ ] **Search conversations**: Full-text search across conversations
- [ ] **Export**: Export conversations to JSON/Markdown
- [ ] **iCloud sync**: Sync conversations across devices
- [ ] **Image generation**: Generate images from text prompts via POST /v1/images/generations (DALL-E, Stable Diffusion, Gemini, etc.)
- [ ] **Audio transcription (Speech-to-Text)**: Record or upload audio for transcription via POST /v1/audio/transcriptions (Whisper, Groq, Deepgram, Gemini)
- [ ] **Text-to-Speech**: Read assistant responses aloud via POST /v1/audio/speech (OpenAI TTS, AWS Polly, ElevenLabs, Gemini TTS)

## Current Phase: 2 — Usability

Focus exclusively on Phase 2 features. Do not over-engineer for future phases.