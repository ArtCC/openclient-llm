---
description: "Use when designing UI, choosing colors, applying Liquid Glass style, configuring Dark Mode, adding SF Symbols, handling accessibility, haptics, or animations in SwiftUI views."
applyTo: "**/*.swift"
---

# Design & UI Guidelines

## Design Philosophy

Native-first design. The app should feel like a first-party Apple app, leveraging system components and platform conventions.

## Liquid Glass (iOS 26+ / macOS 26+)

- Use Liquid Glass materials for toolbars, tab bars, sidebars, and floating elements
- Apply `.glassEffect()` modifier for custom Liquid Glass surfaces
- Let the system handle translucency — don't override with opaque backgrounds
- Navigation bars and tab bars get Liquid Glass automatically with the latest SDK
- Test with varied wallpapers to ensure readability over different backgrounds

## Color System

- **Always use semantic colors** from Asset Catalog — never hardcoded hex/RGB values
- Define colors with both Light and Dark appearance variants in the Asset Catalog
- Use system colors (`Color.primary`, `Color.secondary`, `Color.accentColor`) as base
- Custom colors should be high-contrast and accessible in both modes
- Use `Color(.systemBackground)`, `Color(.secondarySystemBackground)` for surfaces

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

- Always test both Light and Dark appearances
- Use semantic colors and system materials — they adapt automatically
- Images should use template rendering where appropriate
- Asset Catalog images can have Light/Dark variants when needed

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

## Chat UI Patterns

- **Message bubbles**: Rounded rectangles, different alignment/color for user vs assistant
- **Streaming indicator**: Animated cursor or typing indicator while receiving tokens
- **Input area**: Text field with send button, anchored to bottom with keyboard avoidance
- **Scroll behavior**: Auto-scroll to latest message, allow manual scroll to history
- **Code blocks**: Monospaced font, syntax-highlighted background, copy button
