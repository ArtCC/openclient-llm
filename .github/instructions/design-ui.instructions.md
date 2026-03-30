---
description: "Use when designing UI, choosing colors, applying Liquid Glass style, configuring Dark Mode, adding SF Symbols, handling accessibility, haptics, or animations in SwiftUI views."
applyTo: "**/*.swift"
---

# Design & UI Guidelines

## Design Philosophy

Native-first design. The app should feel like a first-party Apple app, leveraging system components and platform conventions.

> **Generic vs. App-Specific**: This document contains both generic Apple design guidelines (reusable across projects) and app-specific configuration for OpenClient LLM. Sections marked with **"App-Specific"** should be adapted when reusing these guidelines in other projects. See the summary at the bottom for a full list.

## Liquid Glass (iOS 26+ / macOS 26+)

### Core Guidelines

- Prefer native Liquid Glass APIs over custom blurs or materials
- Use `GlassEffectContainer` when multiple glass elements coexist in the same view
- Apply `.glassEffect(...)` **after** layout and visual modifiers (padding, frame, font, foregroundStyle)
- Use `.interactive()` only for elements that respond to touch or pointer (buttons, tappable chips)
- Keep shapes consistent across related glass elements for a cohesive look
- Navigation bars, tab bars, and toolbars get Liquid Glass automatically with the iOS 26 SDK — don't add manual glass to them
- Test with varied wallpapers to ensure readability over different backgrounds

### API Reference

#### Glass surfaces

```swift
Text("Label")
    .padding()
    .glassEffect(.regular, in: .rect(cornerRadius: 16))
```

#### Interactive glass (tappable elements)

```swift
Text("Tappable")
    .padding()
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
```

#### Tinted glass

```swift
Text("Tinted")
    .padding()
    .glassEffect(.regular.tint(.accent).interactive(), in: .rect(cornerRadius: 16))
```

#### Grouped glass elements

```swift
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        Image(systemName: "scribble.variable")
            .frame(width: 72, height: 72)
            .font(.system(size: 32))
            .glassEffect()
        Image(systemName: "eraser.fill")
            .frame(width: 72, height: 72)
            .font(.system(size: 32))
            .glassEffect()
    }
}
```

#### Glass button styles

```swift
Button("Action") { }
    .buttonStyle(.glass)

Button("Primary Action") { }
    .buttonStyle(.glassProminent)
```

#### Morphing transitions

```swift
@Namespace private var glassNamespace

// Use glassEffectID for animated transitions between glass elements
view.glassEffect(.regular, in: .capsule)
    .glassEffectID("elementID", in: glassNamespace)
```

### Availability Gating

Always gate Liquid Glass with `#available` and provide a fallback:

```swift
if #available(iOS 26, *) {
    Text("Hello")
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
} else {
    Text("Hello")
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

> **Note**: Since the project minimum deployment is iOS 26, availability checks are only needed if we ever lower the target. For now, use glass APIs directly without `#available`.

### Review Checklist

When reviewing or adding Liquid Glass to a view, verify:

1. **Composition**: Multiple glass views wrapped in `GlassEffectContainer`
2. **Modifier order**: `glassEffect` applied after layout/appearance modifiers
3. **Interactivity**: `.interactive()` only where user interaction exists
4. **Transitions**: `glassEffectID` used with `@Namespace` for morphing animations
5. **Consistency**: Shapes, tinting, and spacing align across the feature
6. **No double glass**: Don't add glass to system components that already have it (NavigationBar, TabBar, Toolbar)

## Color System

### Principles

- **Always use semantic colors** from Asset Catalog — never hardcoded hex/RGB values
- Define colors with both Light and Dark appearance variants in the Asset Catalog
- Use system colors (`Color.primary`, `Color.secondary`, `Color.accentColor`) as base
- Custom colors should be high-contrast and accessible in both modes
- Use `Color(.systemBackground)`, `Color(.secondarySystemBackground)` for surfaces

### App Color Palette

> **App-Specific** — Adapt this palette for your project.

All custom colors are defined in the Asset Catalog with Light and Dark variants:

| Color Name | Usage | Light | Dark |
|---|---|---|---|
| **AccentColor** | Buttons, links, active tab, tint | Teal Blue `#0A84FF` | Teal Blue `#64D2FF` |
| **UserBubble** | User message bubble background | `#0A84FF` (accent) | `#0A4F8A` |
| **UserBubbleText** | Text inside user message bubble | `#FFFFFF` | `#FFFFFF` |
| **AssistantBubble** | Assistant message bubble background | `#E9E9EB` | `#2C2C2E` |
| **AssistantBubbleText** | Text inside assistant message bubble | `#000000` (primary) | `#FFFFFF` (primary) |
| **CodeBlockBackground** | Code block behind text | `#F2F2F7` | `#1C1C1E` |
| **ErrorColor** | Error messages, failed states | System Red | System Red |
| **SuccessColor** | Connection success, confirmations | System Green | System Green |

### Usage Rules

- **Accent color** is the only branded color — everything else uses system semantics
- **Message bubbles**: User = accent-based (right-aligned), Assistant = neutral secondary (left-aligned)
- **Surfaces**: Always `Color(.systemBackground)` and `Color(.secondarySystemBackground)` — never custom background colors
- **Text**: Always `Color.primary` / `Color.secondary` except inside colored user bubbles (fixed white)
- **Destructive actions**: Always `Color.red` (system) — never custom reds
- When in doubt, use a system color over a custom one

## Typography

- Use system fonts exclusively — `Font.body`, `Font.headline`, `Font.caption`, etc.
- Support **Dynamic Type** — never use fixed font sizes
- Use `@ScaledMetric` for spacing that should scale with text size
- Prefer `Text` view with system font styles over custom attributed strings

## Icons

- Use **SF Symbols** for all icons — no custom icon assets unless absolutely necessary
- Apply symbol rendering modes: `.monochrome`, `.hierarchical`, `.palette`, `.multicolor`
- Use symbol effects for animations: `.symbolEffect(.bounce)`, `.symbolEffect(.pulse)`
- Prefer `.symbolVariant(.fill)` for selected/active states

## Dark Mode

- **System-only**: The app follows the system appearance setting — there is no in-app light/dark toggle
- Always test both Light and Dark appearances
- Use semantic colors and system materials — they adapt automatically
- Images should use template rendering where appropriate
- Asset Catalog images can have Light/Dark variants when needed
- Never use `preferredColorScheme()` to force a specific appearance

## Accessibility

- Add `.accessibilityLabel()` to all interactive elements without visible text
- Support **VoiceOver** navigation with logical reading order
- Use `.accessibilityHint()` for non-obvious actions
- Ensure minimum touch target of 44×44pt on iOS
- Test with larger text sizes (Accessibility Inspector)

## Haptics (iOS only)

- Use `UIImpactFeedbackGenerator` for action feedback (send message, button taps)
- Use `UINotificationFeedbackGenerator` for success/error/warning states
- Keep haptics subtle — don't overuse
- Guard with `#if os(iOS)` — no haptics on macOS

## Animations

- Use SwiftUI built-in transitions and animations (`.animation()`, `withAnimation {}`)
- Prefer `.spring()` or `.smooth` for natural motion
- Use `matchedGeometryEffect` for shared element transitions
- Keep animations fast (0.2-0.35s) — never block interaction
- Avoid custom animations when a system component handles it natively

## App Navigation Structure

> **App-Specific** — Adapt tabs, sidebar sections, and navigation hierarchy for your project.

### iOS / iPadOS

- Root navigation: `TabView` with Liquid Glass (automatic on iOS 26+)
- 3 tabs: **Chats** (`bubble.left.and.bubble.right`), **Models** (`cpu`), **Settings** (`gearshape`)
- Each tab wraps its own `NavigationStack`
- On iPadOS, the Chats tab can use `NavigationSplitView` for sidebar layout
- Tab Bar is scalable — new tabs can be added in future phases

### macOS

- Root navigation: `NavigationSplitView` with sidebar (no Tab Bar)
- Sidebar shows conversations list + sections for Models and Settings
- Liquid Glass applies to sidebar and toolbar automatically

## App Flow

> **App-Specific** — Adapt the entry point, onboarding, and routing for your project.

The app has a single entry point (`LaunchView`) that routes based on onboarding state:

```
LaunchView
├── isOnboardingCompleted == false → OnboardingView
│   ├── Step 1: Welcome (app intro + "Get Started" button)
│   ├── Step 2: Server Configuration (base URL + API key + Test Connection)
│   └── Step 3: All Set (confirmation + "Start Chatting" button)
│       └── Saves isOnboardingCompleted = true → HomeView
└── isOnboardingCompleted == true → HomeView (TabView / NavigationSplitView)
```

### LaunchView Rules

- `LaunchView` is the **root view** in both iOS and macOS app entry points
- It reads `isOnboardingCompleted` from `SettingsManager` (UserDefaults)
- No animation on initial routing — instant switch
- After onboarding completes, transition to `HomeView` with a smooth animation

### OnboardingView Rules

- Full-screen flow, no Tab Bar or navigation chrome visible
- Step indicator (dots or progress) at the top
- "Back" button available from Step 2 and 3 (not Step 1)
- **"Skip" button** visible on all steps — user can skip the entire onboarding
- If skipped, `isOnboardingCompleted = true` is still saved, and the user goes directly to `HomeView`
- When skipped, server configuration fields remain empty — the app shows the Settings tab with a prompt to configure the server
- Step 2 must validate server connection before allowing "Next" (but skip bypasses this)
- On completion, persist `isOnboardingCompleted = true` and route to `HomeView`
- User can always configure or reconfigure the server later from Settings

### HomeView Rules

- `HomeView` is the main shell — it hosts `TabView` (iOS/iPadOS) or `NavigationSplitView` (macOS)
- `HomeView` is never wrapped in another `NavigationStack` — each tab manages its own
- Default selected tab on launch: **Chats**

## macOS Window

> **App-Specific** — Adapt window sizes for your project.

### Minimum Size

- Set minimum window size: **800×600 pt** (`minWidth: 800, minHeight: 600`)
- Set default initial size: **1000×700 pt**
- Apply via `.defaultSize()` and `.frame(minWidth:minHeight:)` on the `WindowGroup`

### Persist Window Size & Position

- The app must remember the user's window size and position across launches
- Use `WindowGroup` with a stable identifier so macOS restores state automatically:

```swift
// macOS App entry point
@main
struct OpenClientApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            LaunchView()
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentSize)
    }
}
```

- macOS automatically persists window frame for `WindowGroup` with a stable `id` — no manual `UserDefaults` saving needed
- Do **not** allow the window to resize below the minimum size

## Toolbar Patterns

> **App-Specific** (table below) — Adapt per-screen toolbar actions for your project.

Define standard toolbar actions per screen to keep the UI consistent:

| Screen | Leading | Center / Title | Trailing |
|---|---|---|---|
| **Chats list** | — | "Chats" title | New Chat button (`plus.bubble`) |
| **Chat detail** | Back (auto) | Model name (subtitle style) | Chat info/options (`ellipsis.circle`) |
| **Models list** | — | "Models" title | Refresh button (`arrow.clockwise`) |
| **Settings** | — | "Settings" title | — |
| **Onboarding** | Back (Step 2+) | Step indicator | Skip button |

### Implementation Rules

- Use `.toolbar {}` with `ToolbarItem(placement:)` — never custom HStacks in the navigation bar
- On macOS, add keyboard shortcuts to toolbar actions (e.g., `⌘N` for New Chat)
- Keep toolbar items minimal — max 2-3 per screen
- Use SF Symbols for all toolbar icons

## Search

- Use `.searchable()` modifier on lists that benefit from filtering:
  - **Conversations list**: Filter by conversation title
  - **Models list**: Filter models by name or provider
- Search is **local filtering only** (client-side) — not a server-side search
- Show `ContentUnavailableView.search` when no results match the query
- Place `.searchable()` on the `NavigationStack` or `List` — SwiftUI handles placement automatically

```swift
NavigationStack {
    List(filteredModels) { model in
        ModelRow(model: model)
    }
    .searchable(text: $searchText, prompt: String(localized: "Search models"))
}
```

## Toast Notifications

For transient feedback (connection success, copy confirmation, non-critical errors), use custom toast banners.

### Design

- **Position**: Top of the screen, centered horizontally, below the safe area
- **Style**: Rounded capsule with translucent background (`.ultraThinMaterial`) and subtle shadow
- **Content**: SF Symbol icon + short message text (one line max)
- **Animation**: Slide in from top with `.spring()`, auto-dismiss after **3 seconds**
- **Dismiss**: Auto-dismisses; user can also swipe up to dismiss early
- **Stacking**: Only one toast visible at a time — new toasts replace the current one

### When to Use

> **App-Specific** (table below) — Adapt toast scenarios for your project.

| Scenario | Toast |
|---|---|
| Connection test success | ✅ `checkmark.circle` + "Connected successfully" |
| Message copied | ✅ `doc.on.doc` + "Copied to clipboard" |
| Connection test failed | ✅ `xmark.circle` + "Connection failed" (if inline error also shown) |
| Settings saved | ✅ `checkmark.circle` + "Settings saved" |

### When NOT to Use

- Critical errors that need user action → use inline error state
- Data loss confirmations → use `.confirmationDialog()`
- Loading states → use inline `ProgressView`

### Implementation Pattern

```swift
// Toast overlay applied at HomeView level (once, not per screen)
.overlay(alignment: .top) {
    if let toast = toastManager.current {
        ToastView(toast: toast)
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.top, 8)
    }
}
```

## Keyboard Avoidance (iOS / iPadOS)

**Mandatory rule**: The keyboard must NEVER cover any text input field where the user types. This is a non-negotiable UX requirement.

### Implementation Rules

- Every view with text input must be wrapped in a `ScrollView` or use a layout that adjusts for the keyboard
- SwiftUI's default keyboard avoidance is enabled by default — **do not disable it** with `.ignoresSafeArea(.keyboard)`
- For chat input at the bottom of the screen: the input area must sit above the keyboard when active, pushing content up
- Use `.scrollDismissesKeyboard(.interactively)` on `ScrollView` to allow dismissing the keyboard by dragging down
- On iPadOS with external keyboard: ensure layouts don't break when the software keyboard is hidden

### Chat Input Specific

```swift
// Input area stays above keyboard automatically via safe area
VStack {
    ScrollView {
        // Messages
    }
    .scrollDismissesKeyboard(.interactively)

    ChatInputView() // Anchored to bottom, respects keyboard safe area
}
```

### Form Input Specific

- Forms with multiple fields: wrap in `ScrollView` so the active field scrolls into view
- Use `Form` or `List` containers — they handle keyboard avoidance natively
- After submit, dismiss keyboard explicitly with `FocusState`

### Dismiss Keyboard Rules

- Tapping outside a text field should dismiss the keyboard (use `FocusState` + `.onTapGesture`)
- Sending a message in chat should NOT dismiss the keyboard (user may want to keep typing)
- Submitting a form should dismiss the keyboard
- Swiping down on a `ScrollView` dismisses the keyboard (`.scrollDismissesKeyboard(.interactively)`)

## State Patterns

Every screen must handle all possible data states. Never show a blank screen.

### Loading State

- Use `ProgressView()` centered on screen for initial data load
- For refreshing existing data, prefer inline indicators (e.g., toolbar progress) over full-screen spinners
- Never block interaction with a full-screen opaque loader — use non-blocking indicators when possible
- Streaming responses use an animated typing indicator, not a spinner

### Empty State

- Every list/collection screen must show an empty state when there are no items
- Empty state pattern: **SF Symbol** (large, secondary color) + **title** (headline) + **subtitle** (subheadline, secondary) + **action button** (optional)
- Example: Chats tab with no conversations → `bubble.left.and.bubble.right` icon + "No conversations yet" + "Start a new chat" button
- Use `ContentUnavailableView` (iOS 17+) as the standard empty state component

```swift
ContentUnavailableView {
    Label(String(localized: "No conversations"), systemImage: "bubble.left.and.bubble.right")
} description: {
    Text(String(localized: "Start a new chat to begin"))
} actions: {
    Button(String(localized: "New Chat")) {
        // action
    }
}
```

### Error State

- Show errors inline within the view — avoid blocking `alert()` dialogs for recoverable errors
- Error pattern: SF Symbol (`exclamationmark.triangle`) + error message + "Retry" button
- Use `ContentUnavailableView` for full-screen errors (e.g., failed to load model list)
- For transient errors (network timeout), show a banner or inline message that auto-dismisses or has a manual dismiss
- Connection errors on chat: show inline error below the failed message with a "Retry" option
- Never show raw error codes or technical details to the user — use human-readable localized messages

### No Connection State

- When the server is unreachable, show a clear "No connection" state with a retry action
- Do not silently fail — always inform the user

## Form & Input Patterns

### Text Fields

- Use `TextField` with a clear localized placeholder
- Use `SecureField` for API keys and sensitive data
- Group related fields with `Section` inside `Form` or `List`
- Add `.textContentType()` hint when applicable (`.URL` for server URL)
- Use `.autocorrectionDisabled()` and `.textInputAutocapitalization(.never)` for URLs, API keys, and technical input
- Use `.submitLabel()` to set the keyboard return key (`.done`, `.next`, `.send`)

### Validation

- Validate input inline as the user types or on field exit — not only on submit
- Show validation errors below the field in `.caption` font with destructive color
- Disable "Submit" / "Next" button until required fields are valid
- For server URL: validate format before allowing connection test
- For API key: don't validate format — only test via actual connection

### FocusState

- Use `@FocusState` to manage keyboard focus across multiple fields
- Move focus to the next field on "Next" keyboard button
- Dismiss keyboard on "Done" or successful form submission

## Modals & Sheets

- Use `.sheet()` for modal presentations (new chat, edit settings)
- Use `.confirmationDialog()` for destructive action confirmation — never `alert()` with destructive buttons
- Use `.popover()` on iPadOS/macOS for contextual options
- Sheets should have a clear dismiss action (Cancel button or swipe down)
- Sheets should not be full-screen on iPadOS/macOS — use `.presentationDetents()` to control height when appropriate

### Destructive Actions

- **Always confirm** before deleting conversations, clearing data, or resetting settings
- Use `.confirmationDialog()` with a descriptive title and a `.destructive` role button
- Example: "Delete Conversation?" → "This action cannot be undone." → [Delete] [Cancel]
- Never auto-delete without user confirmation

## Scroll Behavior

### Chat Scroll

- Auto-scroll to the latest message when a new message arrives (both sent and received)
- If the user has scrolled up to read history, do NOT auto-scroll — show a "Scroll to bottom" floating button instead
- Use `ScrollViewReader` with `.scrollTo()` for programmatic scrolling
- Animate scroll-to-bottom with `.smooth` animation

### List Scroll

- Use `.refreshable {}` for pull-to-refresh on lists that load from the server (models list, conversations list)
- Maintain scroll position when data updates (e.g., new conversation added to list)

## Safe Areas

- **Always respect safe areas** — never place interactive content under the notch, Dynamic Island, or home indicator
- Use `.safeAreaInset()` for floating elements that should respect the safe area (e.g., floating action button)
- The chat input bar uses `.safeAreaInset(edge: .bottom)` to anchor above the safe area and keyboard
- On macOS, respect the title bar area — never overlap content with window controls

## Gestures

- Use standard system gestures — swipe to delete in lists, swipe back for navigation
- Do not override system gestures (edge swipe for back navigation)
- Long press on a message for context menu (copy, retry, delete)
- Use `.contextMenu()` or `.swipeActions()` — never custom gesture recognizers for standard interactions

## Chat UI Patterns

- **Message bubbles**: Rounded rectangles, different alignment/color for user vs assistant
- **Streaming indicator**: Animated cursor or typing indicator while receiving tokens
- **Input area**: Text field with send button, anchored to bottom with keyboard avoidance
- **Scroll behavior**: Auto-scroll to latest message, allow manual scroll to history
- **Code blocks**: Monospaced font, syntax-highlighted background, copy button
- **Markdown rendering**: Render assistant messages as Markdown (bold, italic, lists, links, code)
- **Timestamps**: Show message time subtly (secondary color, caption font) — not on every message, use grouping
- **Copy message**: Long press or context menu to copy full message text

> For detailed chat UI implementation patterns, see `chat-visual-style.instructions.md`.

---

## App-Specific Sections Summary

The following sections in this document contain project-specific configuration for **OpenClient LLM** and should be adapted when reusing these guidelines in another project:

| Section | What to adapt |
|---|---|
| **App Color Palette** | Custom color definitions (bubble colors, code block background) |
| **App Navigation Structure** | Specific tabs, sidebar sections, navigation hierarchy |
| **App Flow** | Entry point routing, onboarding steps, screen flow |
| **macOS Window** | Window sizes and resizability |
| **Toolbar Patterns** | Per-screen toolbar action table |
| **Toast Scenarios** | App-specific notification scenarios table |

All other sections are **generic Apple design guidelines** reusable across any SwiftUI project targeting iOS 26+ / macOS 26+.
