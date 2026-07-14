---
description: "Use when writing or reviewing Swift code style (formatting, naming, file layout, MARK sections, comments, and readability). Avoid architecture guidance in this file."
applyTo: "**/*.swift"
---

# Swift Code Style

This file defines preferred style. Existing code is the source of truth for local formatting when it differs from a
generic example; do not perform unrelated cleanup while making a focused change.

## 1) Style Intent

- Keep code easy to scan and maintain.
- Prefer consistency over personal preference.
- Use strict rules where consistency is critical.
- Use recommendations where context can vary.

## 2) Formatting

### Required

- Use 4 spaces for indentation (no tabs).
- Keep one statement per line.
- Keep at most one empty line between code blocks.
- Remove trailing spaces.
- Use one space after commas and around binary operators.
- Keep line length within linter limits.

### Recommended

- Wrap long argument lists one item per line.
- Prefer multi-line formatting when clarity improves, even below max length.

### Good

```swift
let request = ChatCompletionRequest(
    model: model,
    messages: messages,
    stream: true,
    temperature: parameters.temperature
)
```

### Bad

```swift
let request = ChatCompletionRequest(model:model,messages:messages,stream:true,temperature:parameters.temperature)
```

## 3) File Header

### Required

- Use a consistent file header template in all Swift files.
- Keep import statements immediately after the header, separated by one blank line.

### Recommended

- Keep imports sorted and minimal.

### Good

```swift
//
//  ExampleView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/01/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
```

Use the actual target name in the third header line for macOS and extension-owned files. Preserve an existing file's
historical author/copyright spelling unless the task is specifically correcting headers.

## 4) File Layout

Use sections when they improve navigation. The repository does not use one universal section list for every kind of file.

### Required

1. Type declaration
2. `// MARK: - Properties` when the type has a meaningful property group
3. `// MARK: - Init` when an initializer exists
4. A named public section such as `View`, `Input functions`, or `Tests`
5. Protocol conformances in focused extensions
6. `// MARK: - Private` and private helpers near the bottom when practical

### Recommended

- Keep private helpers in extensions at file bottom when that does not prevent access to private stored properties or
  make a large type harder to understand.
- Keep each section compact and cohesive.

### Good

```swift
final class ExampleType {
    // MARK: - Properties

    private let service: ServiceProtocol

    // MARK: - Init

    init(service: ServiceProtocol) {
        self.service = service
    }

    // MARK: - Public

    func execute() {
        prepare()
    }
}

// MARK: - Private

private extension ExampleType {
    func prepare() {}
}
```

### Bad

```swift
final class ExampleType {
    func execute() {}
    private let service: ServiceProtocol
    init(service: ServiceProtocol) { self.service = service }
}
```

## 5) MARK Usage

### Required

- Use `// MARK: - ...` labels for major sections.
- Add one blank line after each MARK label.
- Do not create noisy MARK sections for tiny files.

### Recommended

- Use meaningful labels (`View`, `Input functions`, `Tests`, `Private`) instead of forcing `Public`/`Internal` labels.

### Good

```swift
// MARK: - Public

func send(_ event: Event) {}
```

### Bad

```swift
// MARK: public
func send(_ event: Event) {}
```

## 6) Naming Conventions

### Required

- Use UpperCamelCase for types.
- Use lowerCamelCase for variables, constants, functions, and enum cases.
- Use clear verb-first names for actions (`loadModels`, `refreshData`).
- Use boolean names prefixed with `is`, `has`, or `can`.

### Recommended

- Prefer domain words over abbreviations unless standard (`URL`, `ID`, `API`).
- Keep names explicit even if longer.

### Good

```swift
enum LoadingState {
    case idle
    case loading
}

let isRefreshing: Bool
func fetchAvailableModels() {}
```

### Bad

```swift
enum loading_state {
    case Idle
}

let refresh: Bool
func get() {}
```

## 7) Enums, Structs, and Protocols

### Required

- Prefer `struct` for value semantics.
- Use `enum` for closed sets of states/options.
- Keep protocol names descriptive and capability-oriented.
- Keep associated value labels explicit when they improve readability.

### Recommended

- Group nested enums inside the parent type when scoped to that type.
- Keep enum case naming parallel.

### Good

```swift
enum Event {
    case inputChanged(String)
    case attachmentAdded(data: Data, fileName: String)
}

protocol SettingsStoreProtocol: Sendable {
    func getSelectedModelId() -> String?
}
```

### Bad

```swift
enum Event {
    case a(String)
    case add(Data, String)
}

protocol Manager {
    func run()
}
```

## 8) Function Style

### Required

- Keep function bodies small and focused.
- Use early exits with `guard` for preconditions.
- Prefer `switch` for exhaustive state/event handling.
- Keep argument labels clear at call sites.

### Recommended

- Extract complex logic into private helpers.
- Keep side effects obvious.

### Good

```swift
func send(_ event: Event) {
    guard case .loaded(var loadedState) = state else { return }

    switch event {
    case .inputChanged(let text):
        loadedState.inputText = text
        state = .loaded(loadedState)
    case .sendTapped:
        submitCurrentInput(using: loadedState)
    }
}
```

### Bad

```swift
func send(_ e: Event) {
    if true {
        // many unrelated operations in one block
    }
}
```

## 9) Optionals and Defaults

### Required

- Do not initialize stored optionals with `= nil`.
- Use `guard let` or `if let` for optional unwrapping.
- Avoid force unwraps and force casts.

### Recommended

- Use nil-coalescing only when default behavior is obvious.

### Good

```swift
var selectedModelId: String?

guard let modelId = selectedModelId else { return }
```

### Bad

```swift
var selectedModelId: String? = nil
let modelId = selectedModelId!
```

## 10) Comments and Documentation

### Required

- Write comments only when code intent is not obvious.
- Keep comments short and factual.
- Document safety invariants for any `@unchecked Sendable` usage.

### Recommended

- Prefer expressive names over explanatory comments.
- Use section comments for test grouping.

### Good

```swift
// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsStore: @unchecked Sendable {}
```

### Bad

```swift
// sets value
value = 1
```

## 11) Extensions And File Scope

### Required

- Prefer extensions for protocol conformances and cohesive splits.
- Keep private helpers in a `private extension` at file bottom when practical.
- Add MARK labels for substantial extension blocks.
- Prefer one primary type per file. Small supporting enums, structs, protocols, and private helpers may share the file
  when they are tightly coupled. The repository also uses `Type+Concern.swift` files for large ViewModels and views.

### Recommended

- Keep each extension focused on one purpose.

### Good

```swift
// MARK: - Equatable

extension Conversation: Equatable {}

// MARK: - Private

private extension Conversation {
    func normalizedTitle() -> String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

## 12) Test Style

### Required

- Name tests as `test_<method>_<scenario>_<expectedResult>()`.
- Use `// Given`, `// When`, `// Then` blocks.
- Keep one assertion intent per test.
- Mark each XCTest class `@MainActor`; the test target does not set default actor isolation.

### Recommended

- Use section MARKs to group related test cases.

### Good

```swift
func test_send_viewAppeared_withModels_setsLoadedState() async throws {
    // Given
    mockFetch.result = .success([.init(id: "gpt")])

    // When
    sut.send(.viewAppeared)

    // Then
    XCTAssertEqual(currentModels.count, 1)
}
```

## 13) Linter Alignment

`.swiftlint.yml` is authoritative. Its current limits are:

- File length: warning 500, error 650
- Line length: warning 120, error 150
- Function body length: warning 50, error 80
- Type body length: warning 300, error 400
- Vertical whitespace: max one empty line
- Force unwrap and force cast: errors
- Trailing commas: allowed because the `trailing_comma` rule is disabled

If guide text and linter disagree, update one of them so both stay aligned.

## 14) Anti-Patterns to Avoid

- Inconsistent MARK names/order across files.
- Mixed formatting styles in the same file.
- Large public methods that mix orchestration and implementation details.
- Ambiguous names (`data`, `value`, `manager`) without context.
- Excessive comments explaining obvious code.

## 15) Practical Rule

When unsure between two valid styles, choose the style already used in nearby files unless it conflicts with SwiftLint or
a focused project specification.
