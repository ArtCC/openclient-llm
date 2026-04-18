//
//  GetMemoryContextUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class GetMemoryContextUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: GetMemoryContextUseCase!
    private var mockMemoryManager: MockMemoryManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockMemoryManager = MockMemoryManager()
        sut = GetMemoryContextUseCase(manager: mockMemoryManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockMemoryManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withNoItems_returnsEmpty() {
        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_withAllDisabledItems_returnsEmpty() {
        // Given
        mockMemoryManager.items = [
            MemoryItem(content: "Item 1", isEnabled: false, source: .user),
            MemoryItem(content: "Item 2", isEnabled: false, source: .model)
        ]

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_withEnabledItems_returnsMemoryBlock() {
        // Given
        mockMemoryManager.items = [
            MemoryItem(content: "User likes Swift", isEnabled: true, source: .user),
            MemoryItem(content: "User prefers dark mode", isEnabled: true, source: .model)
        ]

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.hasPrefix("## Memory"))
        XCTAssertTrue(result.contains("- User likes Swift"))
        XCTAssertTrue(result.contains("- User prefers dark mode"))
    }

    func test_execute_withMixedItems_onlyIncludesEnabledOnes() {
        // Given
        mockMemoryManager.items = [
            MemoryItem(content: "Enabled item", isEnabled: true, source: .user),
            MemoryItem(content: "Disabled item", isEnabled: false, source: .user)
        ]

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.contains("- Enabled item"))
        XCTAssertFalse(result.contains("- Disabled item"))
    }

    func test_execute_withSingleEnabledItem_returnsCorrectFormat() {
        // Given
        mockMemoryManager.items = [
            MemoryItem(content: "User is a developer", isEnabled: true, source: .user)
        ]

        // When
        let result = sut.execute()

        // Then
        XCTAssertEqual(result, "## Memory\n- User is a developer")
    }
}
