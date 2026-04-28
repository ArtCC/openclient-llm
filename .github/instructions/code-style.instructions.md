---
description: "Use when writing or reviewing Swift code style (formatting, naming, file layout, MARK sections, comments, and readability). Avoid architecture guidance in this file."
applyTo: "**/*.swift"
---

# Swift Code Style Guide (Reusable)

This guide defines a reusable Swift style baseline focused on code readability and consistency.
It intentionally excludes architecture decisions.

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
//  MyApp
//
//  Created by Author on 01/01/2026.
//

import SwiftUI
```

## 4) Universal File Layout (Same Order for All Files)

Use this section order in every Swift file, regardless of type.

### Required

1. Type declaration
2. `// MARK: - Properties`
3. `// MARK: - Init` (if needed)
4. `// MARK: - Public`
5. `// MARK: - Internal` (if needed)
6. `// MARK: - Private`
7. Protocol conformances in extensions
8. File-private helpers at the bottom

### Recommended

- Keep private helpers in extensions at file bottom when possible.
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

- Use `// MARK: - ...` labels exactly.
- Add one blank line after each MARK label.
- Do not create noisy MARK sections for tiny files.

### Recommended

- Use meaningful labels (`Public`, `Private`, `Tests - sendTapped`) instead of generic names.

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

## 11) Extensions

### Required

- Prefer extensions for protocol conformances.
- Keep private helpers in `private extension` at file bottom.
- Add MARK labels for each extension block.

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

Follow your project linter as the source of truth. Typical baseline:

- Max line length: warning 120, error 150
- Max function body length: warning 50, error 80
- Max type body length: warning 300, error 400
- Vertical whitespace: max one empty line
- Force unwrap / force cast: forbidden

If guide text and linter disagree, update one of them so both stay aligned.

## 14) Anti-Patterns to Avoid

- Inconsistent MARK names/order across files.
- Mixed formatting styles in the same file.
- Large public methods that mix orchestration and implementation details.
- Ambiguous names (`data`, `value`, `manager`) without context.
- Excessive comments explaining obvious code.

## 15) Practical Rule

When unsure between two valid styles, choose the style already used in nearby files.
Consistency with local code always wins.
