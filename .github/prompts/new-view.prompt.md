---
description: "Scaffold a SwiftUI View with its ViewModel following the Event/State pattern and project templates."
agent: "agent"
argument-hint: "View name (e.g., ChatDetail, ServerSettings)"
---

Create a new View named `${input}View` with its ViewModel. Generate all files:

## Files to create

### In the appropriate `openclient-llm/Shared/Features/<Feature>/`

1. **Views/${input}View.swift**

```swift
import SwiftUI

struct ${input}View: View {
    // MARK: - Properties

    @State private var viewModel = ${input}ViewModel()

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                // View content
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ${input}View {}

#Preview {
    ${input}View()
}
```

2. **ViewModels/${input}ViewModel.swift**

```swift
import Foundation

@Observable
@MainActor
final class ${input}ViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {}

    private(set) var state: State

    // MARK: - Init

    init(state: State = .loading) {
        self.state = state
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            state = .loaded(.init())
        }
    }
}

// MARK: - Private

private extension ${input}ViewModel {}
```

### Test (in `openclient-llm-test/`)

3. **${input}ViewModelTests.swift** — Test all Event → State transitions

## Rules

- Follow templates exactly
- Use `.task {}` not `.onAppear`
- Always include `#Preview`
- Use `// MARK: -` sections consistently