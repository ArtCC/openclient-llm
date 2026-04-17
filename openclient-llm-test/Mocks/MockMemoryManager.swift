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

    // MARK: - MemoryManagerProtocol

    func getItems() -> [MemoryItem] {
        items
    }

    func add(_ item: MemoryItem) {
        addedItem = item
        items.append(item)
    }

    func update(_ item: MemoryItem) {
        updatedItem = item
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    func delete(id: UUID) {
        deletedId = id
        items.removeAll { $0.id == id }
    }

    func deleteAll() {
        deleteAllCalled = true
        items.removeAll()
    }
}
