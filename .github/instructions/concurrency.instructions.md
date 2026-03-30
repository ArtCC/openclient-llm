---
description: "Use when writing async/await code, choosing isolation strategy (@MainActor, actor, Sendable), fixing concurrency compiler errors, marking types as Sendable, using @unchecked Sendable, creating Tasks, or reviewing thread-safety."
applyTo: "**/*.swift"
---

# Swift Concurrency Guidelines

Based on the principles from [AvdLee's Swift Concurrency Agent Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill).

## Project Concurrency Settings

This project uses **Swift 6** with these build settings:

| Setting | Value | Effect |
|---------|-------|--------|
| `SWIFT_VERSION` | `6.0` | Full strict concurrency checking |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | All types are `@MainActor` by default |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` | Stricter import visibility |

### What `MainActor` Default Isolation Means

- **Every type, method, and property is `@MainActor` unless explicitly opted out**
- Writing `@MainActor` on ViewModels is redundant but kept for **documentation clarity**
- Types that need to run off the main actor must use `nonisolated`
- Test classes must be `@MainActor` because the types under test are `@MainActor` by default
- This is Apple's recommended approach for UI-driven apps in Swift 6.2

### When to Use `nonisolated`

Mark code as `nonisolated` when it performs genuinely non-UI work:

```swift
// Heavy computation that should not block the main thread
nonisolated func processImage(_ data: Data) async -> UIImage { ... }

// Background data processing
nonisolated func parseJSON(_ data: Data) throws -> [Model] { ... }
```

**Do NOT add `nonisolated` to**: ViewModels, Views, UseCases that call UI-bound code, or any code that touches UI state.

## Core Principles

1. **Understand the default isolation** — all code is `@MainActor` by default; use `nonisolated` only for genuinely background work
2. **Keep explicit `@MainActor` on ViewModels** — redundant but serves as documentation that the type is intentionally UI-bound
3. **Optimize for the smallest safe change** — don't add annotations, wrappers, or abstractions beyond what the compiler requires
4. **Prefer structured concurrency** — `async let`, `TaskGroup` over unstructured `Task { }` whenever possible
5. **`@unchecked Sendable` requires a documented safety invariant** — always add a comment explaining why the type is thread-safe
6. **Prefer value types for Sendable** — structs/enums over classes whenever possible
7. **Never silence warnings without understanding root cause** — every concurrency fix must have a clear, documented reason

## Decision Tree: Choosing Isolation

```
All types are @MainActor by default (project setting).
│
├─ Is the code UI-bound? (ViewModel, View, UI state)
│  └─ Keep default @MainActor — add explicit annotation for clarity on ViewModels ✅
│
├─ Does the code do heavy background work? (image processing, large JSON parsing)
│  └─ Mark as `nonisolated` + make Sendable if crossing boundaries ✅
│
├─ Is it a value type with no mutable shared state?
│  └─ struct — implicitly Sendable if all members are Sendable ✅
│
├─ Is it a reference type wrapping a thread-safe API?
│  └─ @unchecked Sendable + safety comment ✅
│
├─ Is it a reference type with mutable state needing async access?
│  └─ actor (automatically opts out of default MainActor) ✅
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
- Inherits `@MainActor` by default — this is fine since UseCases are lightweight coordinators
- If a UseCase does heavy computation, mark the method `nonisolated`

### Repository

```swift
// Stateless repository (wraps APIClient)
struct SomeRepository: SomeRepositoryProtocol {
    private let apiClient: APIClientProtocol
}

// Stateful repository (local cache) — actor opts out of MainActor default
actor CachedRepository: SomeRepositoryProtocol {
    private var cache: [String: Data] = [:]
}
```

- **Stateless** (API wrapper) → `struct` + Sendable
- **Stateful** (cache, local storage) → `actor` for automatic serialized access (actors ignore default isolation)

### Manager (Transversal Services)

```swift
// Thread-safe wrapper — @unchecked Sendable with documented invariant
// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
}
```

- Use `@unchecked Sendable` **only** when wrapping a proven thread-safe API
- **Always add a safety comment** explaining the invariant
- If the Manager has mutable state not protected by a thread-safe API → use `actor` instead

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
    await viewModel.send(.viewAppeared)
}

.task(id: searchQuery) {
    await viewModel.send(.searchChanged(searchQuery))
}
```

- Automatically cancels when view disappears
- `.task(id:)` cancels and restarts on value change — ideal for search debouncing

### When Unstructured `Task` is Acceptable

```swift
// Fire-and-forget from synchronous context (e.g., button action)
Button("Send") {
    Task {
        await viewModel.send(.sendTapped)
    }
}
```

- Only when bridging sync → async (button actions, gestures)
- The ViewModel handles the work; the Task is just the bridge

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

**Only permitted when ALL of these are true:**

1. The type wraps a proven thread-safe API (Apple docs confirm thread safety)
2. All stored properties are immutable (`let`)
3. A safety invariant comment is present immediately above the class declaration
4. No better alternative exists (actor, struct, Mutex)

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

With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, **all test classes must be `@MainActor`**:

```swift
@MainActor
final class SomeViewModelTests: XCTestCase {
    private var sut: SomeViewModel!
    // ...
}
```

- **This is not a blanket fix** — it's required because the types under test are `@MainActor` by default
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
- [ ] `@MainActor` is only applied to genuinely UI-bound code
- [ ] Every `@unchecked Sendable` has a documented safety invariant
- [ ] Structured concurrency is used where possible
- [ ] Tests still pass with strict concurrency checking
- [ ] No force casts, force unwraps, or unsafe patterns introduced
