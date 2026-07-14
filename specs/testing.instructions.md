---
description: "Use when writing unit tests, integration tests, creating mocks, test doubles, or structuring test files. Covers testing ViewModels, UseCases, Repositories, and API integration."
---

# Testing Guidelines

## Overview

All current tests live in the iOS-hosted `openclient-llm-test/` XCTest target. There is no UI test target and no dedicated
integration-test suite.

## Test Types

### Unit Tests

Test a single unit in isolation with mocked dependencies.

**What to test:**
- **ViewModels**: Event/State transitions, business logic coordination
- **UseCases**: Business rules, data transformations, edge cases
- **Repositories**: Data mapping, caching logic (mock the APIClient)
- **Managers**: Transversal service behavior

Some tests exercise multiple local layers, persistence behavior, cloud-sync mapping, widget snapshots, or streaming logic,
but they remain in the normal feature/core folders. The suite currently contains no tests guarded by `LITELLM_TEST_URL`,
no real-server tests, and no `Integration/` directory. Do not create a network integration suite unless the task explicitly
requires one and its opt-in configuration is defined.

## File Organization

```
openclient-llm-test/
├── Features/
│   └── Chat/
│       ├── ChatViewModelTests.swift
│       ├── ChatViewModelTests+StreamingConcern.swift
│       └── SendMessageUseCaseTests.swift
├── Core/
│   └── Managers/
│       └── SettingsManagerTTSTests.swift
└── Mocks/
    ├── MockChatRepository.swift
    ├── MockAPIClient.swift
    └── MockSettingsManager.swift
```

## Naming Conventions

- Test files: `<TypeUnderTest>Tests.swift`
- Test classes: `<TypeUnderTest>Tests`
- Test methods: `test_<method>_<scenario>_<expectedResult>()`

```swift
func test_send_viewAppeared_setsLoadedState() async { }
func test_execute_withInvalidURL_throwsConnectionError() async { }
func test_fetchModels_serverUnavailable_returnsEmpty() async { }
```

## Test Structure (Given-When-Then)

```swift
import XCTest
@testable import openclient_llm

@MainActor
final class SendMessageUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: SendMessageUseCase!
    private var mockRepository: MockChatRepository!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockRepository = MockChatRepository()
        sut = SendMessageUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withValidMessage_returnsResponse() async throws {
        // Given
        mockRepository.sendMessageResult = .success(.stub())

        // When
        let response = try await sut.execute(message: "Hello")

        // Then
        XCTAssertFalse(response.content.isEmpty)
    }
}
```

## Mocking Pattern

Use protocol-backed dependencies where production code exposes a protocol. Shared mocks live in `Mocks/`; a small helper
used by only one test file may remain private in that file.

```swift
// Protocol (in Shared/Features/Chat/Repositories/)
protocol ChatRepositoryProtocol: Sendable {
    func sendMessage(_ message: String, model: String) async throws -> ChatResponse
}

// Mock (in openclient-llm-test/Mocks/)
// Safety: Only used within serialized @MainActor test methods.
final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var sendMessageResult: Result<ChatResponse, Error> = .failure(MockError.notConfigured)

    func sendMessage(_ message: String, model: String) async throws -> ChatResponse {
        try sendMessageResult.get()
    }
}
```

## Async Testing

Use `async` test methods directly — no need for expectations with modern concurrency:

```swift
func test_fetchModels_returnsModelList() async throws {
    let models = try await sut.execute()
    XCTAssertEqual(models.count, 3)
}
```

Mark the **XCTest class**, not individual methods, `@MainActor`. The test target has no default actor isolation and the
current suite applies this annotation to every XCTest class:

```swift
@MainActor
final class FeatureTests: XCTestCase {
    func test_send_viewAppeared_loadsData() async {
        viewModel.send(.viewAppeared)
        XCTAssertEqual(viewModel.state, .loaded(.init()))
    }
}
```

Large test types may be split with `Type+Concern.swift` extensions or into focused XCTest classes, matching the existing
Chat and Settings suites. Keep each file under the corresponding `Features/<Feature>/` or `Core/<Area>/` path.

## Rules

- Add focused tests for changed behavior at the smallest useful boundary; do not require one ceremonial test file for
  every pass-through type.
- ViewModels should be tested for all Event → State transitions
- Never test private methods — test through the public API
- Use `@testable import` to access internal types
- Keep tests fast — mock all external dependencies in unit tests
- No sleep/delays — use async/await patterns for timing
- `@unchecked Sendable` mocks require the standard safety comment and must only be mutated from the MainActor-isolated
  tests that own them.
