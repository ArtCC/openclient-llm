---
description: "Scaffold a complete feature module with View, ViewModel, UseCase, Repository, Model, and Tests following project architecture."
agent: "agent"
argument-hint: "Feature name (e.g., Chat, Settings, Models)"
---

Create a new feature module named `${input}`. Generate all files following the project architecture:

## Files to create

### Shared code (in `openclient-llm/Shared/Features/${input}/`)

1. **Views/${input}View.swift** — SwiftUI view following the View Template in `AGENTS.md` and `specs/architecture.instructions.md`
2. **ViewModels/${input}ViewModel.swift** — `@Observable @MainActor` ViewModel with the Event/State pattern from those instructions
3. **UseCases/** — Create relevant UseCase(s) with protocol
4. **Repositories/** — Create relevant Repository with protocol
5. **Models/** — Create domain models as Codable structs

### Tests (in `openclient-llm-test/Features/${input}/`)

6. **${input}ViewModelTests.swift** — Test all Event → State transitions
7. **UseCase and Repository tests** — Add isolated tests for every generated UseCase and Repository
8. **Mock files** in `openclient-llm-test/Mocks/` — Mock protocols for dependencies

## Rules

- Follow the ViewModel Event/State template exactly
- Follow the View template exactly (with `@State private var viewModel`, switch on state, `.task {}`)
- Every generated Swift file must start with the repository copyright header, using its actual file name and creation date
- Use `// MARK: -` sections consistently
- All protocols must be `Sendable`
- Prefer `struct` UseCases; use a class only when the operation requires shared mutable state or reference semantics
- UseCases and Repositories must have protocol definitions
- Every test class must be `@MainActor`
- Test naming: `test_<method>_<scenario>_<expectedResult>()`
