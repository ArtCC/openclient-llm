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

Keep shared logic, ViewModels, UseCases, Repositories, and Models in `openclient-llm/Shared/`. Only platform-specific views go in the respective target folders (`openclient-llm/Views/` for iOS, `openclient-llm-macOS/Views/` for macOS).

For shared views that differ slightly by platform, use `#if os()` inside the view. Only create separate view files per target when the UI is fundamentally different.

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

### iOS / iPadOS — Tab Bar (Liquid Glass)

The app uses a `TabView` with Liquid Glass style as the root navigation on iOS and iPadOS. The Tab Bar gets Liquid Glass automatically with the iOS 26+ SDK.

| Tab | SF Symbol | Content |
|---|---|---|
| **Chats** | `bubble.left.and.bubble.right` | Conversation list + chat view (`NavigationStack`) |
| **Models** | `cpu` | Available models from the LiteLLM server |
| **Settings** | `gearshape` | Server configuration, API key, preferences |

```swift
TabView {
    Tab(String(localized: "Chats"), systemImage: "bubble.left.and.bubble.right") {
        ChatsNavigationView()
    }
    Tab(String(localized: "Models"), systemImage: "cpu") {
        ModelsView()
    }
    Tab(String(localized: "Settings"), systemImage: "gearshape") {
        SettingsView()
    }
}
```

- Each tab contains its own `NavigationStack` for internal navigation
- On iPadOS, the Tab Bar adapts to the larger screen — conversations can use `NavigationSplitView` inside the Chats tab for sidebar layout
- Tabs are scalable — future features (e.g., "Images" for image generation) can be added as new tabs

### macOS — NavigationSplitView with Sidebar

macOS does **not** use Tab Bar. Instead, use `NavigationSplitView` with a sidebar as the root navigation:

- Sidebar shows conversation list + navigation to Models and Settings
- Detail view shows the active chat
- Use toolbar items and keyboard shortcuts for macOS-native interaction

### Navigation Destinations

- Define navigation destinations with enums conforming to `Hashable`
- Use `NavigationStack` with typed `NavigationPath` for push navigation within each tab/section

## Layout Guidelines

- **iOS**: `TabView` (Liquid Glass) as root → `NavigationStack` inside each tab
- **iPadOS**: `TabView` (Liquid Glass) as root → `NavigationSplitView` inside Chats tab for sidebar + detail
- **macOS**: `NavigationSplitView` with sidebar, toolbar items, keyboard shortcuts — no Tab Bar

## Common Patterns

- Use `.task {}` modifier for async data loading on view appear
- Use `ViewThatFits` or `GeometryReader` sparingly for adaptive layouts
- Prefer built-in SwiftUI components over custom implementations
- Use `.searchable()` for search functionality
- Use `.sheet()`, `.popover()`, `.confirmationDialog()` for modal presentations