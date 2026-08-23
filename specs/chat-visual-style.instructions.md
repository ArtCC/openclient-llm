---
description: "Use when designing chat interfaces, message layouts, input bars, empty states, streaming indicators, suggestion chips, or any conversational AI UI patterns."
applyTo: "**/*.swift"
---

# Chat App Visual Style Guide

## Design Philosophy

Modern, clean conversational interface inspired by leading AI chat applications. Focus on content readability, minimal chrome, and clear role differentiation between user and assistant messages.

## Message Layout

### General Principles

- Messages flow vertically in a scrollable container
- Clear visual distinction between user and assistant roles
- Content-first: minimize decorative elements around message text
- Generous spacing between messages for readability (12-16pt)
- New message rows currently use an opacity transition. Do not document or add slide motion unless the interaction is
  deliberately redesigned.

### User Messages

- Right-aligned with left margin (minimum 60pt spacer on leading side)
- Accent-tinted regular glass background
- Rounded container with moderate corner radius (16-20pt)
- Standard body text with fixed white foreground on the accent-tinted glass
- No avatar needed — right alignment is sufficient to identify role

### Assistant Messages

- Left-aligned, extending to near full width (small trailing margin, minimum 40pt)
- **No bubble background** — plain text directly on the view background
- Small role indicator icon on the leading edge (avatar)
- Standard body text with primary foreground color
- Markdown rendering for formatted content (bold, italic, inline code, links)

### Role Indicators (Avatars)

- Small circular icon (28-32pt) on the leading edge of assistant messages only
- Glass effect on the avatar circle for visual consistency
- Avatar top-aligned with the first line of message content
- Use SF Symbols or app-branded icon for the assistant
- User messages do NOT need avatars — alignment differentiates roles

### Metadata

- Message timestamps use `.caption2`/tertiary styling and sit outside message surfaces. User timestamps are below and
  trailing the accent-tinted glass; assistant timestamps are trailing in the metadata row.
- Optional token usage is shown in the completed assistant message metadata row.
- While the user manually scrolls through history, a centered, noninteractive glass date capsule identifies the day of
  the first visible message. Visibility observations are presentation-only and must never drive automatic scrolling.
- Do not make timestamps hover-only; they must remain available on touch platforms.

## Input Bar

### Design

- Floating pill/capsule shape at the bottom of the chat
- Glass effect background (`.glassEffect(.regular, in: .capsule)`)
- Multi-line text input with dynamic height (1-5 lines)
- No visible border on the text field — use `.plain` text field style; the glass provides the visual boundary
- Generous padding inside the pill (horizontal: 16pt, vertical: 10pt)
- Horizontal padding outside the pill for screen margins

### Send Button

- Circular filled icon positioned INSIDE the input pill, trailing edge
- Icon: `arrow.up.circle.fill` with accent color
- Appears when trimmed input is non-empty and a model is selected; otherwise a microphone action is shown when speech
  input is available
- Smooth scale + opacity transition when appearing/disappearing
- Keep a minimum 44×44pt hit target even though the current icon uses `.font(.title)`

### Stop Button (During Streaming)

- Replaces the send button when a response is being streamed
- Icon: `stop.circle.fill` with destructive/red style
- Tapping cancels the current stream immediately
- Same size and position as the send button for visual consistency

### Placeholder

- Conversational tone: short and inviting (e.g., "Message...")
- `.secondary` foreground color (default TextField behavior)

## Empty State / Welcome Screen

### Layout

- Centered vertically within the scrollable message area
- Maximum width constraint (~400pt) for readability on larger screens
- Content: icon + greeting + optional subtitle + suggestion chips

### Welcome Content

- Large assistant icon (60-80pt) with glass effect circle background
- Friendly greeting text uses Poppins SemiBold relative to `.title2`; most surrounding text uses semantic system fonts
- Optional subtitle in `.subheadline` font, `.secondary` color
- Vertically centered with generous spacing between elements

### Suggestion Chips

- 2-4 tappable prompt suggestions below the welcome area
- Arranged in a 2-column grid (`LazyVGrid` with 2 flexible columns, 12pt spacing)
- Each chip: SF Symbol icon + short text label
- Glass effect with `.interactive()` for tap feedback
- Rounded rectangle shape (cornerRadius 14-16pt)
- `.subheadline` font, left-aligned content inside the chip
- Tapping a chip immediately sends the prompt as a message
- Chips are only visible when there are no messages

## Model / Agent Selector

- Positioned as the navigation bar's **principal** item (centered in toolbar)
- Uses `Menu` with a label showing the current model name + chevron-down icon
- `.headline` font weight for the model name, `.caption2` for the chevron
- `lineLimit(1)` to prevent overflow on long model names
- Tapping opens a dropdown/popup with available models
- Selected model shows a checkmark in the menu
- Fallback text when no model is selected (e.g., "No Model")
- No additional icons (cpu, brain, etc.) — keep it clean: just text + chevron

## Streaming Indicators

### Typing Cursor

- Append a blinking solid cursor character (`█`) to the final streaming text block.
- Toggle it every 500 ms while streaming and remove it when streaming completes.
- Before answer or reasoning content exists, show a static localized `Thinking...` label. Once text exists, the integrated
  cursor is the answer-stream indicator.
- Streaming reasoning may blink the Thinking disclosure label on the same discrete 500 ms cadence; do not use a continuous
  phase animation inside scroll targets.

### Progressive Rendering

- Tokens appear immediately as they arrive from the stream
- After the first fragment, coalesce routine text mutations on a 50 ms cadence; payload size must not force additional
  same-frame publications, while lifecycle and non-text events may flush once to preserve content and event order
- Use `ScrollViewReader` with explicit top and bottom sentinels; never bind `ScrollPosition` to the chat scroll view
- Keep message rows in an eager `VStack`. `LazyVStack` can enter a non-converging layout pass when upward user scrolling
  overlaps live message updates, freezing both iOS and macOS
- Starting a response and each coalesced text publication scroll to the bottom without animation only while bottom-follow
  mode remains active
- Manual scrolling detaches bottom-follow immediately; only a new response or the bottom button resumes it
- Do not show a loading spinner for answer generation; use the current cursor/Thinking states

## Message Entry Animations

- Current message rows use `.transition(.opacity)`.
- Top/bottom scroll buttons appear only after manual detachment and do not animate the scroll container.
- Do not add a container-wide animation keyed to every token or message mutation; streaming updates should remain stable
  and readable.

## Markdown Rendering

### Inline Formatting (Minimum Viable)

- Use `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace` parsing option
- Supports: **bold**, *italic*, `inline code`, [links], ~~strikethrough~~
- Graceful fallback to plain text if markdown parsing fails
- Apply to assistant messages only — user messages stay as plain text
- While an answer streams, render its source as immediate plain text with the integrated cursor; apply full Markdown once
  after streaming completes
- Parse structural and inline Markdown outside `MainActor`, cache the rendered result, and never invoke
  `AttributedString(markdown:)` from a SwiftUI `body`

### Code Blocks (Current)

- `MarkdownParser` splits fenced blocks from text and headings.
- `CodeBlockView` uses `.system(.body, design: .monospaced)`, selectable text, and horizontal scrolling.
- A language label, or localized "Code" fallback, appears in the header.
- The copy button changes to a green checkmark/"Copied" state for two seconds.
- The surface is `.ultraThinMaterial` with a subtle rounded stroke. Syntax highlighting is not implemented.

## Color Guidelines

### Principles

- Use semantic system colors — adapts automatically to Light/Dark mode
- Chat background: `Color(.systemBackground)`
- User message bubble: glass effect (no custom color needed, glass adapts)
- Assistant message: no background — text on systemBackground
- Input bar: glass effect
- Avatars: glass effect circles with accent-tinted icons
- Error states: `Color.red` (system) for banners and indicators

### Dark Mode

- Glass effects adapt automatically — no manual color changes needed
- Ensure sufficient contrast for text on glass surfaces
- Test with varied wallpapers / desktop backgrounds

## Navigation Context

### Chat as Primary View

- The chat interface should feel like the primary experience of the app
- Navigation title area is used for the model selector, not a static title
- Minimal toolbar items — only what's essential for the current context
- Navigation bar uses inline display mode to maximize content area

## macOS Chat Adaptations

The chat interface shares the same core layout across platforms, but macOS requires subtle adjustments for a native desktop feel.

### Input Bar

- Same glass capsule input bar as iOS
- On macOS, the text field should use `.textFieldStyle(.plain)` — consistent with iOS (glass provides the chrome)
- Send/stop button: use `.buttonStyle(.plain)` since it's an icon inside the glass pill — same as iOS
- No `.submitLabel()` on macOS — handle Enter key via `.onSubmit {}` (same behavior, no modifier needed)

### Message Bubbles

- Same layout rules as iOS (user right-aligned with glass, assistant left-aligned without background)
- On macOS, user bubble glass may render slightly differently due to window backgrounds — test with various desktop wallpapers
- Message timestamps and the transient date capsule use the same shared behavior as iOS; there is no macOS-only hover state

### Action Buttons Inside Messages

- Most inline message actions use `.buttonStyle(.plain)`.
- `CodeBlockView` currently uses `.bordered` with `.controlSize(.small)` for its labeled copy action on macOS and plain
  style on iOS. Preserve that implemented distinction unless the code-block header is redesigned.

### Scroll Behavior

- The main macOS chat scroll keeps native indicators. `CodeBlockView` intentionally hides its horizontal indicator while
  retaining horizontal scrolling for long lines.
- `.scrollDismissesKeyboard()` is iOS-only — omit on macOS (already guarded by `#if os(iOS)`)
- Elastic overscroll is native on macOS — don't disable it
- On macOS the keyboard notification for scroll adjustment is not needed — the keyboard doesn't overlay content

### Model Selector (Toolbar)

- Same `Menu` + chevron pattern as iOS, with Poppins SemiBold model text and middle truncation at 200 points
- The shared Chat toolbar places it as a principal item where supported; verify placement on both platforms
- macOS toolbar has built-in glass — don't add extra glass to the selector label

### Suggestion Chips

- Same 2-column grid with glass interactive chips
- On macOS, chips respond to hover (`.interactive()` handles this automatically with Liquid Glass)
- Ensure chips have pointer cursor on hover (system default for interactive glass)

### Empty State

- Same layout as iOS — centered icon + greeting + chips
- On macOS with larger windows, the `maxWidth(400)` constraint keeps it readable
- No adjustment needed — the constraint handles both platforms

---

# Annex: App-Specific — OpenClient

> The following rules are specific to the OpenClient project. Adjust for other projects as needed.

## Assistant Identity

- **Avatar SF Symbol**: `sparkles` (represents AI/generative capability)
- **Avatar tint**: `Color.accentColor`
- No user avatar displayed — alignment differentiates roles

## Suggestion Prompts

`ConversationStartersManager` currently chooses four random items from this localized pool:

| Icon | English Key | Purpose |
|---|---|---|
| `lightbulb` | "Explain a complex topic simply" | Knowledge/explanation |
| `pencil.and.outline` | "Write a creative story" | Creative writing |
| `chevron.left.forwardslash.chevron.right` | "Help me with my code" | Code assistance |
| `globe` | "Translate text to another language" | Translation |
| `book` | "Summarize a long text" | Summarization |
| `questionmark.bubble` | "Answer a tricky question" | General questions |
| `text.badge.checkmark` | "Review and improve my writing" | Editing |
| `brain.head.profile` | "Brainstorm ideas for a project" | Ideation |

All prompts must be localized via `String(localized:)` for every supported language.

## Input Placeholder

- English: `"Message..."`
- Must be localized for all supported languages

## Empty State Greeting

- English: `"How can I help you?"`
- Must be localized for all supported languages

## Model Selector

- Placed at `ToolbarItem(placement: .principal)` in the ChatView toolbar
- No navigation title displayed (set to empty string)
- Chevron icon: `chevron.down` in `.caption2` font, `.secondary` style
