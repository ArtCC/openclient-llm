---
description: "Scaffold a complete feature module with View, ViewModel, UseCase, Repository, Model, and Tests following project architecture."
agent: "agent"
argument-hint: "Feature name (e.g., Chat, Settings, Models)"
---

Create a new feature module named `${input}`. Generate all files following the project architecture:

## Files to create

### Shared code (in `openclient-llm/Shared/Features/${input}/`)

1. **Views/${input}View.swift** — SwiftUI view following the View Template from copilot-instructions.md
2. **ViewModels/${input}ViewModel.swift** — @Observable @MainActor ViewModel with Event/State pattern from copilot-instructions.md
3. **UseCases/** — Create relevant UseCase(s) with protocol
4. **Repositories/** — Create relevant Repository with protocol
5. **Models/** — Create domain models as Codable structs

### Tests (in `openclient-llm-test/Features/${input}/`)

6. **${input}ViewModelTests.swift** — Test all Event → State transitions
7. **Mock files** in `openclient-llm-test/Mocks/` — Mock protocols for dependencies

## Rules

- Follow the ViewModel Event/State template exactly
- Follow the View template exactly (with `@State private var viewModel`, switch on state, `.task {}`)
- Use `// MARK: -` sections consistently
- All protocols must be `Sendable`
- UseCase and Repository must have protocol definitions
- Test naming: `test_<method>_<scenario>_<expectedResult>()`