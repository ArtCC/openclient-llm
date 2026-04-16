//
//  MemoryViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class MemoryViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case addItem(content: String)
        case editItem(id: UUID, content: String)
        case toggleItem(id: UUID)
        case deleteItem(id: UUID)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var items: [MemoryItem] = []
    }

    private(set) var state: State

    private let memoryManager: MemoryManagerProtocol
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        memoryManager: MemoryManagerProtocol = MemoryManager()
    ) {
        self.state = state
        self.memoryManager = memoryManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadItems()
            startObservingCloudChanges()
        case .addItem(let content):
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let item = MemoryItem(content: trimmed, source: .user)
            memoryManager.add(item)
            loadItems()
        case .editItem(let id, let content):
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  case .loaded(let loadedState) = state,
                  var existing = loadedState.items.first(where: { $0.id == id }) else { return }
            existing.content = trimmed
            memoryManager.update(existing)
            loadItems()
        case .toggleItem(let id):
            guard case .loaded(let loadedState) = state,
                  var existing = loadedState.items.first(where: { $0.id == id }) else { return }
            existing.isEnabled.toggle()
            memoryManager.update(existing)
            loadItems()
        case .deleteItem(let id):
            memoryManager.delete(id: id)
            loadItems()
        }
    }
}

// MARK: - Private

private extension MemoryViewModel {
    func loadItems() {
        let items = memoryManager.getItems().sorted { $0.createdAt > $1.createdAt }
        state = .loaded(LoadedState(items: items))
    }

    func startObservingCloudChanges() {
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: MemoryManager.memoryDidChangeExternallyNotification
            ) {
                guard let self, !Task.isCancelled else { break }
                self.loadItems()
            }
        }
    }
}
