---
description: "Use when planning features, prioritizing work, defining scope, or deciding what to implement next in the project roadmap."
---

# Feature Roadmap

## Development Approach

Build incrementally from less to more. Each phase should result in a functional app.

## Phase 13 — Apple Platform Extensions

Goal: Extend the app across Apple platforms and system surfaces — widgets, watch, notifications, and quick-access controls.

- [x] **Control Center toggle (iOS 18+)**: A `ControlWidget` (WidgetKit) that adds a "New Chat" button to the iOS Control Center. Defined as a `ControlWidgetButton` with a `bubble.left.fill` SF Symbol icon and a label. The action is an `AppIntent` (reuses the existing intents from Phase 12 Apple Shortcuts integration) that opens the app in a blank conversation via `openclient://new-chat`. Lives inside the same `OpenClientWidgets` extension target used by the WidgetKit widgets — no additional target needed. The user adds it manually to their Control Center layout (iOS 18+ drag-and-drop customization). Provides the fastest possible access to a new chat: one swipe from any screen or the lock screen + one tap.
- [ ] **Widgets (WidgetKit)**: New `OpenClientWidgets` extension target with a `WidgetBundle` exposing four widgets. All widgets share data via an **App Group** (`group.com.artcc.openclient-llm`): conversations, pinned state, settings, and server URL are read from `UserDefaults(suiteName:)` and the shared `FileManager` container. The app writes to the App Group container on every data change and calls `WidgetCenter.shared.reloadAllTimelines()` to keep widgets fresh. Deep links use the existing `openclient://` URL scheme. Widgets:
  - **New Chat (Small)**: `StaticConfiguration` with a single timeline entry. Shows the app icon and "New Chat" label. Tap opens the app in a blank conversation via `widgetURL(URL(string: "openclient://new-chat"))`.
  - **Search (Small)**: `StaticConfiguration` with a single timeline entry. Shows a magnifying glass icon and "Search" label. Tap opens the app directly in the Search tab with the keyboard focused via `widgetURL(URL(string: "openclient://search"))`. Requires adding `case search` to `URLSchemeAction` and handling it in `URLSchemeParser` and `URLSchemeManager`.
  - **Quick Actions (Medium)**: `StaticConfiguration` with two `Link` buttons side by side in an `HStack` — "New Chat" (`bubble.left.and.bubble.right`) and "Search" (`magnifyingglass`). Each button has a large icon and a label below. Uses the same deep links as the Small widgets.
  - **Conversations Overview (Large)**: `TimelineProvider` with 4–5 recent conversations. Header row with "Recent" title and a "New Chat" `Link` button. Each conversation row shows title, last message preview (truncated), and model name. Rows and button use deep links. Implementation order: (1) App Group infrastructure + shared data provider, (2) New Chat + Search + Quick Actions, (3) Overview.

## Phase 14 — watchOS Companion App

Goal: Bring OpenClient to Apple Watch as a minimalist wrist assistant for quick Q&A.

- [ ] **watchOS companion app**: Minimalist wrist assistant for quick Q&A — dictate or type a prompt, get a concise response, done. New `openclient-llm-watchOS` target in Xcode. **No duplicated networking or model code**: the watch target shares `APIClient`, request/response models (`ChatCompletionRequest`, `ChatCompletionResponse`, `ModelsResponse`, etc.), `SettingsManager`, and `KeychainManager` from `Shared/Core/` by adding those files to the watchOS target membership. New code is limited to watch-specific Views, a lightweight ViewModel, and the `WCSession` onboarding handler. **Onboarding flow**: (1) first launch shows a setup screen: "Open OpenClient on your iPhone to connect"; (2) the iPhone app detects `WCSession.isWatchAppInstalled` and prompts the user to send configuration; (3) iPhone sends a single `updateApplicationContext` with `serverURL`, `apiKey`, and `selectedModelId`; (4) watch receives, saves to local `UserDefaults`, shows "Connected ✓", and transitions to chat. If the user later changes server config on iPhone, another `updateApplicationContext` is sent (idempotent — always delivers the latest state). After setup the watch is **fully independent** — all API calls go directly from the watch via its own WiFi/LTE connection, no further WatchConnectivity traffic. **Screens**: (A) **Chat** — large microphone button for dictation, text input (Scribble/keyboard), send button, scrollable response area, "Open on iPhone" button at the bottom (via Handoff / `NSUserActivity`); (B) **History** — last 10–15 queries stored in local `UserDefaults` (question + response), tap to view full response; (C) **Settings** — read-only display of active model and server status (online/offline). Requests use `stream: false` (no streaming on small screen), a fixed system prompt injected for brevity ("Respond concisely in 2–3 sentences maximum"), and a 15-second timeout. **Complications**: circular (app icon, tap to open chat) and inline ("Ask AI" quick access from watch face).

## Phase 15 — visionOS Native App

Goal: Bring OpenClient to Apple Vision Pro as a native spatial computing experience.

- [ ] **visionOS native app**: Native Vision Pro experience for conversational AI. New `openclient-llm-visionOS` target in Xcode. **No duplicated code**: shares `APIClient`, all request/response models, `SettingsManager`, `KeychainManager`, UseCases, and Repositories from `Shared/` by adding files to the visionOS target membership. New code is limited to visionOS-specific Views and any platform adaptations. **Window-based UI** (no immersive spaces needed for a chat app): (A) **Main window** — `NavigationSplitView` with conversation list sidebar and chat detail, adapted from the existing iPad/macOS layout; (B) **Ornament input bar** — the chat input bar rendered as a visionOS `.ornament` anchored below the main window (standard visionOS pattern for toolbars); (C) **Glass material** — use visionOS native `.regularMaterial` glass backgrounds for message bubbles and UI surfaces (not Liquid Glass which is iOS 26-specific); (D) **Multi-window support** — users can open multiple conversations in separate floating windows via `WindowGroup` and `openWindow(value:)`, allowing side-by-side comparison of different chats in spatial space; (E) **Voice input** — prominent dictation button as primary input method (typing is less comfortable on Vision Pro). All standard features work: streaming, markdown rendering, attachments, model selection, system prompt, memory, web search, agent tool calling. Development and testing primarily via the **visionOS Simulator** in Xcode; final testing on hardware via beta testers with Vision Pro devices.

## Current Phase: 13 — Apple Platform Extensions

Focus exclusively on Phase 13 features. Do not over-engineer for future phases.