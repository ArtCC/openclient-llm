---
description: "Use when creating or modifying SwiftUI views, building multi-platform UI, adapting layouts for iOS/iPadOS/macOS, or working with platform-specific navigation and controls."
applyTo: "**/*.swift"
---

# SwiftUI Multi-Platform Patterns

## Platform Adaptation

Use conditional compilation for platform-specific UI:

```swift
#if os(iOS)
// iPhone-specific layout
#elseif os(macOS)
// macOS-specific layout (sidebar, toolbar, menu bar)
#endif
```

Keep shared logic and models in `Core/` and `Features/*/Models/`. Only views and platform-specific presentation go in `Platform/`.

## View Structure

- One View per file, named after the view
- Always include `#Preview` at the bottom
- Use `@State` for view-local state, `@Environment` for injected dependencies
- Use `@Observable` view models injected via `@State private var` in the view
- Views switch on `viewModel.state` to render `.loading` / `.loaded` states
- Use `.task {}` instead of `.onAppear` for async loading

```swift
struct ChatView: View {
    // MARK: - Properties

    @State private var viewModel = ChatViewModel()

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                // Feature content
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ChatView {}

#Preview {
    ChatView()
}
```

## Navigation

- Use `NavigationStack` with typed `NavigationPath` on iOS
- Use `NavigationSplitView` for sidebar-based layouts (macOS, iPadOS)
- Define navigation destinations with enums conforming to `Hashable`

## Layout Guidelines

- **iOS**: Tab-based navigation (`TabView`), full-screen chat
- **iPadOS**: `NavigationSplitView` with sidebar for conversations
- **macOS**: `NavigationSplitView` with sidebar, toolbar items, keyboard shortcuts

## Common Patterns

- Use `.task {}` modifier for async data loading on view appear
- Use `ViewThatFits` or `GeometryReader` sparingly for adaptive layouts
- Prefer built-in SwiftUI components over custom implementations
- Use `.searchable()` for search functionality
- Use `.sheet()`, `.popover()`, `.confirmationDialog()` for modal presentations