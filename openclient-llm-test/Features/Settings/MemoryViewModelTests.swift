//
//  MemoryViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MemoryViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: MemoryViewModel!
    private var mockMemoryManager: MockMemoryManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockMemoryManager = MockMemoryManager()
        sut = MemoryViewModel(memoryManager: mockMemoryManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockMemoryManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_withNoItems_loadsEmptyList() {
        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.items.isEmpty)
    }

    func test_send_viewAppeared_withItems_loadsItems() {
        // Given
        let item = MemoryItem(content: "User likes Swift", source: .user)
        mockMemoryManager.items = [item]

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.items.count, 1)
        XCTAssertEqual(loadedState.items.first?.content, "User likes Swift")
    }

    // MARK: - Tests — addItem

    func test_send_addItem_savesItemWithUserSource() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.addItem(content: "Prefers dark mode"))

        // Then
        XCTAssertEqual(mockMemoryManager.addedItem?.content, "Prefers dark mode")
        XCTAssertEqual(mockMemoryManager.addedItem?.source, .user)
        XCTAssertTrue(mockMemoryManager.addedItem?.isEnabled ?? false)
    }

    func test_send_addItem_withEmptyContent_doesNotSave() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.addItem(content: "   "))

        // Then
        XCTAssertNil(mockMemoryManager.addedItem)
    }

    func test_send_addItem_trimsWhitespace() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.addItem(content: "  Swift developer  "))

        // Then
        XCTAssertEqual(mockMemoryManager.addedItem?.content, "Swift developer")
    }

    func test_send_addItem_updatesLoadedState() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.addItem(content: "New item"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.items.count, 1)
    }

    // MARK: - Tests — editItem

    func test_send_editItem_updatesExistingItem() {
        // Given
        let item = MemoryItem(content: "Original", source: .user)
        mockMemoryManager.items = [item]
        sut.send(.viewAppeared)

        // When
        sut.send(.editItem(id: item.id, content: "Updated"))

        // Then
        XCTAssertEqual(mockMemoryManager.updatedItem?.content, "Updated")
        XCTAssertEqual(mockMemoryManager.updatedItem?.id, item.id)
    }

    func test_send_editItem_withEmptyContent_doesNotUpdate() {
        // Given
        let item = MemoryItem(content: "Original", source: .user)
        mockMemoryManager.items = [item]
        sut.send(.viewAppeared)

        // When
        sut.send(.editItem(id: item.id, content: "  "))

        // Then
        XCTAssertNil(mockMemoryManager.updatedItem)
    }

    // MARK: - Tests — toggleItem

    func test_send_toggleItem_flipsIsEnabled() {
        // Given
        let item = MemoryItem(content: "Test", isEnabled: true, source: .user)
        mockMemoryManager.items = [item]
        sut.send(.viewAppeared)

        // When
        sut.send(.toggleItem(id: item.id))

        // Then
        XCTAssertEqual(mockMemoryManager.updatedItem?.id, item.id)
        XCTAssertFalse(mockMemoryManager.updatedItem?.isEnabled ?? true)
    }

    // MARK: - Tests — deleteItem

    func test_send_deleteItem_removesItem() {
        // Given
        let item = MemoryItem(content: "To delete", source: .user)
        mockMemoryManager.items = [item]
        sut.send(.viewAppeared)

        // When
        sut.send(.deleteItem(id: item.id))

        // Then
        XCTAssertEqual(mockMemoryManager.deletedId, item.id)
    }

    func test_send_deleteItem_updatesLoadedState() {
        // Given
        let item = MemoryItem(content: "To delete", source: .user)
        mockMemoryManager.items = [item]
        sut.send(.viewAppeared)

        // When
        sut.send(.deleteItem(id: item.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.items.isEmpty)
    }
}
