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
- New messages appear with entry animations (slide + fade)

### User Messages

- Right-aligned with left margin (minimum 60pt spacer on leading side)
- Subtle background treatment (glass effect or soft tinted background) — NOT bold colored bubbles
- Rounded container with moderate corner radius (16-20pt)
- Standard body text, primary foreground color
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

### Timestamps

- Hidden by default to keep the interface clean
- `.caption2` font, `.tertiary` foreground style
- Positioned below the message content
- Consider showing on interaction (tap on iOS, hover on macOS) in future iterations

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
- Appears only when there is non-empty text AND a model/agent is selected
- Smooth scale + opacity transition when appearing/disappearing
- Minimum touch target: 44×44pt via `.font(.title2)`

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
- Friendly greeting text in `.title2` or `.title` font, `.primary` color
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

- Append a cursor character (`▌`) to the end of the streaming message text
- The visual effect of streaming tokens + cursor creates a "typing" feel
- Cursor is removed when streaming completes
- **NO separate "Generating..." label** — the cursor integrated with the text IS the indicator

### Progressive Rendering

- Tokens appear immediately as they arrive from the stream
- Smooth scroll-to-bottom as new content arrives
- No loading spinners during active streaming (only cursor)

## Message Entry Animations

- New messages appear with a combined transition: slide from bottom + fade in
- Animation: `.spring(duration: 0.3)` or `.easeOut(duration: 0.25)` timing
- Apply `.animation()` on the message container, keyed to message count
- Each message has `.transition(.move(edge: .bottom).combined(with: .opacity))`

## Markdown Rendering

### Inline Formatting (Minimum Viable)

- Use `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace` parsing option
- Supports: **bold**, *italic*, `inline code`, [links], ~~strikethrough~~
- Graceful fallback to plain text if markdown parsing fails
- Apply to assistant messages only — user messages stay as plain text

### Code Blocks (Future Enhancement)

- Distinct background color (semantic asset catalog color)
- Monospaced font (`.system(.body, design: .monospaced)`)
- Horizontal scroll for long lines
- Optional copy button in the top-right corner
- Language label when specified in the markdown fence

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

---

# Annex: App-Specific — OpenClient LLM

> The following rules are specific to the OpenClient LLM project. Adjust for other projects as needed.

## Assistant Identity

- **Avatar SF Symbol**: `sparkles` (represents AI/generative capability)
- **Avatar tint**: `Color.accentColor`
- No user avatar displayed — alignment differentiates roles

## Suggestion Prompts

Default suggestion chips for the empty state:

| Icon | English Key | Purpose |
|---|---|---|
| `lightbulb` | "Explain a complex topic simply" | Knowledge/explanation |
| `pencil.and.outline` | "Write a creative story" | Creative writing |
| `chevron.left.forwardslash.chevron.right` | "Help me with my code" | Code assistance |
| `globe` | "Translate text to another language" | Translation |

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
