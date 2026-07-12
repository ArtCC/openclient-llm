---
description: "Use when writing unit tests, integration tests, creating mocks, test doubles, or structuring test files. Covers testing ViewModels, UseCases, Repositories, and API integration."
---

# Testing Guidelines

## Overview

All tests live in the `openclient-llm-test/` target, linked to the iOS target. Tests cover shared logic only — no UI tests.

## Test Types

### Unit Tests

Test a single unit in isolation with mocked dependencies.

**What to test:**
- **ViewModels**: Event/State transitions, business logic coordination
- **UseCases**: Business rules, data transformations, edge cases
- **Repositories**: Data mapping, caching logic (mock the APIClient)
- **Managers**: Transversal service behavior

### Integration Tests

Test real interactions between layers or with external services.

**What to test:**
- **API integration**: Real HTTP calls against a LiteLLM server (guarded by environment variable or test configuration)
- **Repository + APIClient**: Verify end-to-end data flow without mocks

Integration tests that require a running server should be skipped by default and only run explicitly.

## File Organization

```
openclient-llm-test/
├── Features/
│   └── Chat/
│       ├── ChatViewModelTests.swift
│       ├── SendMessageUseCaseTests.swift
│       └── ChatRepositoryTests.swift
├── Core/
│   ├── Networking/
│   │   └── APIClientTests.swift
│   └── Managers/
│       └── AuthManagerTests.swift
├── Integration/
│   └── LiteLLMIntegrationTests.swift
└── Mocks/
    ├── MockChatRepository.swift
    ├── MockAPIClient.swift
    └── MockAuthManager.swift
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

Use protocols for all dependencies. Create mock implementations in `Mocks/`:

```swift
// Protocol (in Shared/Features/Chat/Repositories/)
protocol ChatRepositoryProtocol: Sendable {
    func sendMessage(_ message: String, model: String) async throws -> ChatResponse
}

// Mock (in openclient-llm-test/Mocks/)
final class MockChatRepository: ChatRepositoryProtocol {
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

For testing `@MainActor` ViewModels, mark the test method with `@MainActor`:

```swift
@MainActor
func test_send_viewAppeared_loadsData() async {
    viewModel.send(.viewAppeared)
    XCTAssertEqual(viewModel.state, .loaded(.init()))
}
```

## Integration Tests

Guard integration tests that need a running LiteLLM server:

```swift
final class LiteLLMIntegrationTests: XCTestCase {
    private var isServerAvailable: Bool {
        ProcessInfo.processInfo.environment["LITELLM_TEST_URL"] != nil
    }

    func test_healthCheck_serverResponds() async throws {
        try XCTSkipUnless(isServerAvailable, "LiteLLM server not configured")

        // Real API call
    }
}
```

## Rules

- Every UseCase and Repository must have corresponding tests
- ViewModels should be tested for all Event → State transitions
- Never test private methods — test through the public API
- Use `@testable import` to access internal types
- Keep tests fast — mock all external dependencies in unit tests
- No sleep/delays — use async/await patterns for timing
