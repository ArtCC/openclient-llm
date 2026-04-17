//
//  SaveMemoryToolTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SaveMemoryToolTests: XCTestCase {
    // MARK: - Properties

    private var sut: SaveMemoryTool!
    private var mockMemoryManager: MockMemoryManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockMemoryManager = MockMemoryManager()
        sut = SaveMemoryTool(memoryManager: mockMemoryManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockMemoryManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests — definition

    func test_definition_hasCorrectName() {
        XCTAssertEqual(sut.definition.function.name, "save_memory")
    }

    func test_definition_hasContentParameter() {
        XCTAssertNotNil(sut.definition.function.parameters.properties["content"])
        XCTAssertTrue(sut.definition.function.parameters.required.contains("content"))
    }

    // MARK: - Tests — execute

    func test_execute_withValidContent_savesMemoryItemWithModelSource() async throws {
        // Given
        let arguments = #"{"content": "User is a Swift developer"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNotNil(mockMemoryManager.addedItem)
        XCTAssertEqual(mockMemoryManager.addedItem?.content, "User is a Swift developer")
        XCTAssertEqual(mockMemoryManager.addedItem?.source, .model)
        XCTAssertTrue(mockMemoryManager.addedItem?.isEnabled ?? false)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_withEmptyContent_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"content": "   "}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.addedItem)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_withInvalidJSON_returnsErrorMessage() async throws {
        // Given
        let arguments = "not-json"

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.addedItem)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_withMissingContentKey_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"other": "value"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertNil(mockMemoryManager.addedItem)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_trimsWhitespaceFromContent() async throws {
        // Given
        let arguments = #"{"content": "  trimmed content  "}"#

        // When
        _ = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockMemoryManager.addedItem?.content, "trimmed content")
    }
}
