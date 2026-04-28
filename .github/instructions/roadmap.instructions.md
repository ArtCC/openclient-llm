---
description: "Use when planning features, prioritizing work, defining scope, or deciding what to implement next in the project roadmap."
---

# Feature Roadmap

## Development Approach

Build incrementally from less to more. Each phase should result in a functional app.

## Phase 14 — watchOS Companion App

Goal: Bring OpenClient to Apple Watch as a minimalist wrist assistant for quick Q&A.

- [ ] **watchOS companion app**: Minimalist wrist assistant for quick Q&A — dictate or type a prompt, get a concise response, done. New `openclient-llm-watchOS` target in Xcode. **No duplicated networking or model code**: the watch target shares `APIClient`, request/response models (`ChatCompletionRequest`, `ChatCompletionResponse`, `ModelsResponse`, etc.), `SettingsManager`, and `KeychainManager` from `Shared/Core/` by adding those files to the watchOS target membership. New code is limited to watch-specific Views, a lightweight ViewModel, and the `WCSession` onboarding handler. **Onboarding flow**: (1) first launch shows a setup screen: "Open OpenClient on your iPhone to connect"; (2) the iPhone app detects `WCSession.isWatchAppInstalled` and prompts the user to send configuration; (3) iPhone sends a single `updateApplicationContext` with `serverURL`, `apiKey`, and `selectedModelId`; (4) watch receives, saves to local `UserDefaults`, shows "Connected ✓", and transitions to chat. If the user later changes server config on iPhone, another `updateApplicationContext` is sent (idempotent — always delivers the latest state). After setup the watch is **fully independent** — all API calls go directly from the watch via its own WiFi/LTE connection, no further WatchConnectivity traffic. **Screens**: (A) **Chat** — large microphone button for dictation, text input (Scribble/keyboard), send button, scrollable response area, "Open on iPhone" button at the bottom (via Handoff / `NSUserActivity`); (B) **History** — last 10–15 queries stored in local `UserDefaults` (question + response), tap to view full response; (C) **Settings** — read-only display of active model and server status (online/offline). Requests use `stream: false` (no streaming on small screen), a fixed system prompt injected for brevity ("Respond concisely in 2–3 sentences maximum"), and a 15-second timeout. **Complications**: circular (app icon, tap to open chat) and inline ("Ask AI" quick access from watch face).

## Phase 15 — visionOS Native App

Goal: Bring OpenClient to Apple Vision Pro as a native spatial computing experience.

- [ ] **visionOS native app**: Native Vision Pro experience for conversational AI. New `openclient-llm-visionOS` target in Xcode. **No duplicated code**: shares `APIClient`, all request/response models, `SettingsManager`, `KeychainManager`, UseCases, and Repositories from `Shared/` by adding files to the visionOS target membership. New code is limited to visionOS-specific Views and any platform adaptations. **Window-based UI** (no immersive spaces needed for a chat app): (A) **Main window** — `NavigationSplitView` with conversation list sidebar and chat detail, adapted from the existing iPad/macOS layout; (B) **Ornament input bar** — the chat input bar rendered as a visionOS `.ornament` anchored below the main window (standard visionOS pattern for toolbars); (C) **Glass material** — use visionOS native `.regularMaterial` glass backgrounds for message bubbles and UI surfaces (not Liquid Glass which is iOS 26-specific); (D) **Multi-window support** — users can open multiple conversations in separate floating windows via `WindowGroup` and `openWindow(value:)`, allowing side-by-side comparison of different chats in spatial space; (E) **Voice input** — prominent dictation button as primary input method (typing is less comfortable on Vision Pro). All standard features work: streaming, markdown rendering, attachments, model selection, system prompt, memory, web search, agent tool calling. Development and testing primarily via the **visionOS Simulator** in Xcode; final testing on hardware via beta testers with Vision Pro devices.

## Current Phase: 14 — watchOS Companion App

Focus exclusively on Phase 14 features. Do not over-engineer for future phases.