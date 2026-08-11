//
//  MockMemoryManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
@MainActor
final class MockMemoryManager: MemoryManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var items: [MemoryItem] = []
    var addedItem: MemoryItem?
    var updatedItem: MemoryItem?
    var deletedId: UUID?
    var deleteAllCalled: Bool = false
    var synchronizeCalled: Bool = false
    var deleteAllError: Error?
    var synchronizeError: Error?
    var mutationError: Error?

    // MARK: - MemoryManagerProtocol

    func getItems() -> [MemoryItem] {
        items
    }

    func synchronize() async throws {
        synchronizeCalled = true
        if let synchronizeError { throw synchronizeError }
    }

    func add(_ item: MemoryItem) async throws {
        if let mutationError { throw mutationError }
        addedItem = item
        items.append(item)
    }

    func update(_ item: MemoryItem) async throws {
        if let mutationError { throw mutationError }
        updatedItem = item
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    func delete(id: UUID) async throws {
        if let mutationError { throw mutationError }
        deletedId = id
        items.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        if let deleteAllError { throw deleteAllError }
        deleteAllCalled = true
        items.removeAll()
    }
}
