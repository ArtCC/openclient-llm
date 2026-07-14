---
description: "Scaffold a UseCase with protocol and unit test following project architecture."
agent: "agent"
argument-hint: "UseCase name (e.g., SendMessage, FetchModels)"
---

Create a new UseCase named `${input}UseCase`. Generate all files:

## Files to create

### UseCase (in the appropriate `openclient-llm/Shared/Features/<Feature>/UseCases/`)

1. **${input}UseCase.swift** — UseCase implementation with protocol

```swift
protocol ${input}UseCaseProtocol: Sendable {
    func execute(...) async throws -> ...
}

struct ${input}UseCase: ${input}UseCaseProtocol {
    // MARK: - Properties

    private let repository: <Repository>Protocol

    // MARK: - Init

    init(repository: <Repository>Protocol) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(...) async throws -> ... {
        // Business logic
    }
}
```

### Test (in `openclient-llm-test/Features/<Feature>/`)

2. **${input}UseCaseTests.swift** — Unit tests with mocked repository, Given-When-Then pattern

## Rules

- Protocol must be `Sendable`
- Prefer a `struct`; use a class only when the operation requires shared mutable state or reference semantics
- Inject dependencies through init
- One public `execute` method per UseCase
- Every generated Swift file must start with the repository copyright header, using its actual file name and creation date
- The test class must be `@MainActor`
- Test naming: `test_execute_<scenario>_<expectedResult>()`
