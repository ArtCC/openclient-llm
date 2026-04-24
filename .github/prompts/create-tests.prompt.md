---
description: "Add unit tests for existing code that lacks coverage: ViewModels, UseCases, Repositories, and Parsers."
agent: "agent"
---

Add unit tests for existing code that has no or insufficient test coverage.

## Input required

Before starting, ask the user for:
1. **Target** — which file, type, or feature to cover (e.g. `OrderViewModel`, `SaveOrderUseCase`, all of `Features/Order/`)
2. **Priority** — full coverage or just critical paths

---

## Process

### 1. Analyse existing code

- Read the target source file(s) fully
- List every public method and every `Event` → `State` transition to cover
- Check `openclient-llm-test/` for any existing tests to avoid duplication

### 2. Create or locate the test file

- Path: `openclient-llm-test/Features/<FeatureName>/<TypeName>Tests.swift`
- If testing a Core type (Parser, Manager): `openclient-llm-test/Core/<TypeName>Tests.swift`
- File header:
  ```swift
  //
  //  <TypeName>Tests.swift
  //  openclient-llm-test
  //
  //  Created by Arturo Carretero Calvo on DD/MM/YYYY.
  //  Copyright © YYYY Arturo Carretero Calvo. All rights reserved.
  //
  ```

### 3. Create mocks if needed

- One mock per protocol dependency, in `openclient-llm-test/Mocks/Mock<ProtocolName>.swift`
- Pattern:
  ```swift
  // Safety: Only used within serialized @MainActor test methods.
  final class Mock<ProtocolName>: <ProtocolName>, @unchecked Sendable {
      // Configurable stubs: var result / var error
  }
  ```
- Only create a mock if one does not already exist

### 4. Write the tests

Follow these coverage requirements per type:

**ViewModel (`@MainActor final class`)**
- Every `Event` → `State` transition
- Error path (repository/useCase throws)
- Loading state set before async work completes

**UseCase (`struct`)**
- Success path with valid input
- Error path (dependency throws)
- Edge cases (empty input, nil optional, boundary values)

**Repository (mocked data source)**
- CRUD operations
- Data mapping correctness
- Cache invalidation (if stateful `actor`)

**Parser (pure function)**
- Valid input → correct model
- Invalid input → correct error type
- Round-trip: parse → serialize → parse yields same result

### 5. Naming convention

```
test_<methodOrEvent>_<condition>_<expectedResult>()
```

Examples:
```swift
func test_send_viewAppeared_setsLoadingState() { }
func test_execute_withValidInput_returnsItem() async throws { }
func test_execute_whenRepositoryThrows_setsErrorState() async { }
func test_parse_withMissingRequiredField_throwsError() throws { }
```

### 6. Run and verify

- Run `mcp_xcodebuildmcp_test_sim` or the `run-tests` prompt
- All new tests must pass
- No previously passing tests may regress

### 7. Report

- List every test added with its name and what it covers
- Final count: total tests / passed / failed

---

## Rules

- Never write a test that always passes regardless of the implementation
- Never use `XCTAssertTrue(true)` or equivalent no-op assertions
- Use `XCTAssertEqual`, `XCTAssertThrowsError`, `XCTAssertNil`, `XCTUnwrap` — be specific
- Test classes must be `@MainActor` when testing `@MainActor` types
- Do not add `@MainActor` per method if the class is already `@MainActor`
- Do not test private methods directly — test through the public API
- Do not modify source code to make it easier to test (except extracting a protocol if genuinely needed)
