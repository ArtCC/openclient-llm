---
description: "Use when writing async/await code, choosing isolation strategy (@MainActor, actor, Sendable), fixing concurrency compiler errors, marking types as Sendable, using @unchecked Sendable, creating Tasks, or reviewing thread-safety."
applyTo: "**/*.swift"
---

# Swift Concurrency Guidelines

Based on the principles from [AvdLee's Swift Concurrency Agent Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill).

## Project Concurrency Settings

The iOS and macOS **app targets** use Swift 6, approachable concurrency, member import visibility, and
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Shared code is compiled in those app targets and therefore receives that
default there.

The `openclient-llm-test`, `ShareExtension`, and `WidgetsExtension` target configurations currently do **not** set
`SWIFT_DEFAULT_ACTOR_ISOLATION`. Do not describe the whole project or every target as implicitly main-actor isolated.

### What `MainActor` Default Isolation Means

- Declarations compiled by either app target are main-actor isolated by default unless explicitly opted out.
- Writing `@MainActor` on ViewModels is redundant but kept for **documentation clarity**
- Shared DTOs, request/response models, parsing helpers, and other values that must cross isolation boundaries commonly use
  `nonisolated` declarations plus `Sendable` in the current code.
- Every XCTest class is explicitly `@MainActor`. This is necessary because the test target has no MainActor default and
  most production declarations it accesses are main-actor isolated in the host app.

### When to Use `nonisolated`

Mark code as `nonisolated` when it performs genuinely non-UI work:

```swift
// Heavy computation that should not block the main thread
nonisolated func processImage(_ data: Data) async -> UIImage { ... }

// Background data processing
nonisolated func parseJSON(_ data: Data) throws -> [Model] { ... }
```

Do not add `nonisolated` to ViewModels, Views, or code that touches UI-bound state. A UseCase may be nonisolated when its
entire dependency graph and values are safe to cross actor boundaries; decide from behavior rather than layer name.

## Core Principles

1. **Understand target scope** — app/shared code has a MainActor default; tests and extensions do not
2. **Keep explicit `@MainActor` on ViewModels** — redundant but serves as documentation that the type is intentionally UI-bound
3. **Optimize for the smallest safe change** — don't add annotations, wrappers, or abstractions beyond what the compiler requires
4. **Prefer structured concurrency** — `async let`, `TaskGroup` over unstructured `Task { }` whenever possible
5. **`@unchecked Sendable` requires a documented safety invariant** — always add a comment explaining why the type is thread-safe
6. **Prefer value types for Sendable** — structs/enums over classes whenever possible
7. **Never silence warnings without understanding root cause** — every concurrency fix must have a clear, documented reason

## Decision Tree: Choosing Isolation

```
Declarations in the iOS/macOS app targets are @MainActor by default.
│
├─ Is the code UI-bound? (ViewModel, View, UI state)
│  └─ Keep default @MainActor — add explicit annotation for clarity on ViewModels ✅
│
├─ Must the declaration run or be constructed away from MainActor?
│  └─ Mark the appropriate declaration `nonisolated` and make crossing values Sendable ✅
│
├─ Is it a value type with no mutable shared state?
│  └─ struct — implicitly Sendable if all members are Sendable ✅
│
├─ Is it a reference type wrapping a thread-safe API?
│  └─ @unchecked Sendable + safety comment ✅
│
├─ Is it a reference type with mutable state needing serialized async access?
│  └─ Consider an actor and verify protocol isolation at call sites ✅
│
├─ Need synchronous fine-grained locking?
│  └─ Mutex (iOS 18+) ✅
│
└─ Is it a function/closure crossing isolation boundaries?
   └─ @Sendable ✅
```

## Layer-Specific Patterns

### ViewModel

```swift
@Observable
@MainActor  // Redundant (default) but kept for documentation clarity
final class FeatureViewModel {
    private(set) var state: State
}
```

- `@MainActor` is implicit (project default) but **keep it explicit** for clarity
- **Justification**: state is read/written by SwiftUI on the main thread
- Use `@Observable` (never `ObservableObject` / `@Published`)

### UseCase

```swift
protocol SomeUseCaseProtocol: Sendable {
    func execute() async throws -> Result
}

struct SomeUseCase: SomeUseCaseProtocol {
    private let repository: SomeRepositoryProtocol
}
```

- **`struct`** — value type, implicitly Sendable if all members are Sendable
- **Protocol marked `: Sendable`** — ensures all conforming types are safe to pass across isolation domains
- In app targets, an unannotated UseCase inherits the MainActor default. This is acceptable for lightweight orchestration.
- Use explicit `nonisolated` only when all accessed dependencies and transferred values support it.

### Repository

```swift
// Stateless repository (wraps APIClient)
struct SomeRepository: SomeRepositoryProtocol {
    private let apiClient: APIClientProtocol
}

// Preferred option for mutable state that genuinely needs actor serialization
actor CachedRepository: SomeRepositoryProtocol {
    private var cache: [String: Data] = [:]
}
```

- **Stateless** (API wrapper) → `struct` + Sendable
- **Stateful** (cache, local storage) -> choose an actor, MainActor isolation, or a documented thread-safe API according to
  the required calling semantics. Current repositories are mostly structs/classes rather than actors.

### Manager (Transversal Services)

```swift
// Thread-safe wrapper — @unchecked Sendable with documented invariant
// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
}
```

- Prefer `@unchecked Sendable` for immutable wrappers around proven thread-safe APIs.
- Current cloud/profile/memory observers also use it for framework callback state constrained to the main thread. Such an
  exception must document the complete synchronization invariant and keep `nonisolated(unsafe)` storage narrowly scoped.
- If mutable state has no proven serialization rule, use an actor or MainActor isolation instead.

### APIClient

```swift
struct APIClient: APIClientProtocol, Sendable {
    private let session: URLSession
    private let baseURL: URL
}
```

- `struct` — `URLSession` is thread-safe, client holds no mutable state
- Protocol marked `: Sendable`

## Tasks and SwiftUI

### Preferred: `.task` Modifier

```swift
.task {
    viewModel.send(.viewAppeared)
}

.task(id: searchQuery) {
    viewModel.send(.searchChanged(searchQuery))
}
```

- Automatically cancels when view disappears
- `.task(id:)` cancels and restarts on value change — ideal for search debouncing

### When Unstructured `Task` is Acceptable

```swift
// Bridge to a genuinely async API from a synchronous action.
Button("Send") {
    Task {
        await asyncService.send()
    }
}
```

- Only when bridging synchronous UI callbacks to genuinely async work.
- Current ViewModel `send(_:)` methods are generally synchronous event entry points and launch owned work internally, so
  views should call them directly rather than wrapping every event in `Task`.

### Avoid

```swift
// ❌ Detached tasks (lose priority, cancellation, task-locals)
Task.detached { ... }

// ❌ Unstructured tasks when structured alternatives exist
func loadData() async {
    Task { await fetchA() }  // ❌
    Task { await fetchB() }  // ❌
}

// ✅ Use async let or TaskGroup instead
func loadData() async {
    async let a = fetchA()
    async let b = fetchB()
    let results = await (a, b)
}
```

## Sendable Rules

### Value Types (Structs/Enums)

- **Internal types**: Implicitly Sendable if all members are Sendable — no annotation needed
- **Public types**: Require explicit `Sendable` conformance

### Reference Types (Classes)

Priority order:
1. Can it be a struct? → Refactor
2. Immutable (`final` + all `let` properties) → `Sendable`
3. Mutable + UI-bound → `@MainActor` (implicit Sendable)
4. Mutable + async → `actor`
5. Wraps thread-safe API → `@unchecked Sendable` + safety comment
6. `@unchecked Sendable` without justification → **NEVER**

### Closures

```swift
// Closures crossing isolation boundaries must be @Sendable
// Captured values must be Sendable and immutable
let query = "search" // let, not var
store.filter { contact in
    contact.name.contains(query) // ✅ Immutable capture
}
```

## `@unchecked Sendable` Policy

Preferred immutable-wrapper case:

1. The type wraps a proven thread-safe API.
2. Stored dependencies are immutable (`let`).
3. A safety invariant comment is present immediately above the declaration.
4. No better checked alternative exists.

Current code also has framework-observer exceptions with mutable callback tokens or metadata queries. For those, the
comment must identify the actor/thread that owns every mutable property; narrowly scoped `nonisolated(unsafe)` may only
express that documented framework constraint. `@unchecked Sendable` is never permission for unsynchronized mutation.

```swift
// ✅ Correct: documented invariant
// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsManager: @unchecked Sendable { ... }

// ❌ Wrong: no documentation, mutable state
final class Cache: @unchecked Sendable {
    var items: [String: Data] = [:]  // Not thread-safe!
}
```

## Test Mocks

```swift
// @unchecked Sendable is acceptable for test mocks
// Safety: Only used within serialized @MainActor test methods.
final class MockSettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    var isOnboardingCompleted: Bool = false
}
```

- Mocks may use `@unchecked Sendable` because tests are serialized
- Add safety comment explaining test-only scope

## Testing and `@MainActor`

The test target does not set default actor isolation. **Every XCTest class must be explicitly `@MainActor`** to match the
hosted app code and the existing suite:

```swift
@MainActor
final class SomeViewModelTests: XCTestCase {
    private var sut: SomeViewModel!
    // ...
}
```

- This is the project convention for all XCTest classes, including tests of otherwise nonisolated helpers.
- Without `@MainActor`, the test can't access isolated properties/methods synchronously
- All `setUp` / `tearDown` / test methods inherit the `@MainActor` isolation

## Common Diagnostics

| Error | Question to Ask | Fix |
|-------|----------------|-----|
| "Main actor-isolated ... cannot be used from nonisolated context" | Is the code truly UI-bound? | If yes → `@MainActor` on caller. If no → `await MainActor.run { }` only when needed |
| "Capture of ... with non-sendable type" | Can the type be made Sendable? | Prefer struct. If class → check Sendable rules above |
| "Non-sendable type ... cannot cross actor boundary" | Does the type need to cross boundaries? | Make Sendable, or restructure to avoid crossing |
| "Actor-isolated property ... cannot be mutated from nonisolated context" | Should the caller be isolated? | Pass as `isolated` parameter, or await the actor method |
| "Static property ... is not concurrency-safe" | Is it a singleton? | `@MainActor static`, or `static let` + Sendable |

## Verification Checklist

Before considering a concurrency fix complete:

- [ ] The fix addresses the root cause, not just the symptom
- [ ] Explicit `@MainActor` is retained on ViewModels and XCTest classes; other annotations reflect actual isolation
- [ ] Every `@unchecked Sendable` has a documented safety invariant
- [ ] Structured concurrency is used where possible
- [ ] Tests still pass with strict concurrency checking
- [ ] No force casts, force unwraps, or unsafe patterns introduced
