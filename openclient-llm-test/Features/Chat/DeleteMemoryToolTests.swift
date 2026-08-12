//
//  DeleteMemoryToolTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class DeleteMemoryToolTests: XCTestCase {
    // MARK: - Properties

    private var sut: DeleteMemoryTool!
    private var mockMemoryManager: MockMemoryManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockMemoryManager = MockMemoryManager()
        sut = DeleteMemoryTool(memoryManager: mockMemoryManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockMemoryManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests — definition

    func test_definition_hasCorrectName() {
        XCTAssertEqual(sut.definition.function.name, "delete_memory")
    }

    func test_definition_hasContentParameter() {
        XCTAssertNotNil(sut.definition.function.parameters.properties["content"])
        XCTAssertTrue(sut.definition.function.parameters.required.contains("content"))
    }

    // MARK: - Tests — execute with invalid input

    func test_execute_withInvalidJSON_returnsErrorMessage() async throws {
        // Given
        let arguments = "not-json"

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.deletedId)
        XCTAssertTrue(result.text.contains("No content provided"))
    }

    func test_execute_withEmptyContent_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"content": "   "}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.deletedId)
        XCTAssertTrue(result.text.contains("No content provided"))
    }

    func test_execute_withMissingContentKey_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"other": "value"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.deletedId)
        XCTAssertTrue(result.text.contains("No content provided"))
    }

    // MARK: - Tests — execute with valid input

    func test_execute_exactMatch_deletesMemoryItem() async throws {
        // Given
        let item = MemoryItem(content: "User likes Swift")
        mockMemoryManager.items = [item]
        let arguments = #"{"content": "User likes Swift"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockMemoryManager.deletedId, item.id)
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertFalse(result.text.contains("No memory item found"))
    }

    func test_execute_substringMatch_deletesMemoryItem() async throws {
        // Given
        let item = MemoryItem(content: "User is a Swift developer working on iOS")
        mockMemoryManager.items = [item]
        let arguments = #"{"content": "Swift developer"}"#

        // When
        _ = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockMemoryManager.deletedId, item.id)
    }

    func test_execute_exactMatchTakesPrecedence_overSubstring() async throws {
        // Given
        let exactItem = MemoryItem(content: "iOS")
        let substringItem = MemoryItem(content: "iOS development tools")
        mockMemoryManager.items = [exactItem, substringItem]
        let arguments = #"{"content": "iOS"}"#

        // When
        _ = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockMemoryManager.deletedId, exactItem.id)
    }

    func test_execute_caseInsensitiveMatching() async throws {
        // Given
        let item = MemoryItem(content: "USER PREFERENCES")
        mockMemoryManager.items = [item]
        let arguments = #"{"content": "user preferences"}"#

        // When
        _ = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockMemoryManager.deletedId, item.id)
    }

    func test_execute_noMatch_returnsNotFoundMessage() async throws {
        // Given
        mockMemoryManager.items = [MemoryItem(content: "Some other memory")]
        let arguments = #"{"content": "nonexistent content"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.deletedId)
        XCTAssertTrue(result.text.contains("No memory item found"))
    }

    func test_execute_successfulDelete_postsNotification() async throws {
        // Given
        let item = MemoryItem(content: "Test memory")
        mockMemoryManager.items = [item]
        let arguments = #"{"content": "Test memory"}"#
        let notificationName = MemoryManager.memoryDidChangeExternallyNotification

        let expectation = expectation(forNotification: notificationName, object: nil)
        expectation.isInverted = false

        // When
        _ = try await sut.execute(arguments: arguments)

        // Then
        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_execute_deleteFails_throwsFailure() async {
        // Given
        let expectedError = NSError(domain: "DeleteMemoryToolTests", code: 1)
        let item = MemoryItem(content: "Test memory")
        mockMemoryManager.items = [item]
        mockMemoryManager.mutationError = expectedError

        // When
        do {
            _ = try await sut.execute(arguments: #"{"content": "Test memory"}"#)
            XCTFail("Expected delete failure")
        } catch {
            // Then
            XCTAssertEqual(error as NSError, expectedError)
        }
    }
}
