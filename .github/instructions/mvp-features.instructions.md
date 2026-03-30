---
description: "Use when planning features, prioritizing work, defining MVP scope, or deciding what to implement next in the project roadmap."
---

# MVP Features Roadmap

## Development Approach

Build incrementally from less to more. Each phase should result in a functional app.

## Phase 1 — Foundation (MVP Core)

Goal: Basic chat with a LiteLLM server.

- [ ] **Server configuration**: Settings screen to input base URL and optional API key
- [ ] **Connection test**: Health check to validate server is reachable
- [ ] **Model listing**: Fetch and display available models from LiteLLM
- [ ] **Basic chat**: Send a message, receive a response (non-streaming)
- [ ] **Streaming chat**: SSE streaming for real-time token display
- [ ] **Conversation view**: Chat bubble UI with user/assistant messages

## Phase 2 — Usability

Goal: Daily-usable chat experience.

- [ ] **Conversation persistence**: Save/load conversations locally (SwiftData)
- [ ] **Conversation list**: Sidebar/list of past conversations
- [ ] **New conversation**: Create new chats, select model per conversation
- [ ] **System prompt**: Configurable system prompt per conversation
- [ ] **Copy/share messages**: Copy individual messages, share conversations
- [ ] **Markdown rendering**: Render assistant responses with Markdown + code blocks

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

## Current Phase: 1 — Foundation

Focus exclusively on Phase 1 features. Do not over-engineer for future phases.
