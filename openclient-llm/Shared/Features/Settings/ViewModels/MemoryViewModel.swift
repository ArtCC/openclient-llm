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
        case retrySynchronization
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var items: [MemoryItem] = []
        var errorMessage: String?
        var isSynchronizing: Bool = false
    }

    private(set) var state: State

    private let memoryManager: MemoryManagerProtocol
    private let appReviewManager: AppReviewManagerProtocol
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        appReviewManager: AppReviewManagerProtocol = AppReviewManager()
    ) {
        self.state = state
        self.memoryManager = memoryManager
        self.appReviewManager = appReviewManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadItems()
            synchronizeItems()
            startObservingCloudChanges()
        case .addItem(let content):
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let item = MemoryItem(content: trimmed, source: .user)
            performMutation { [memoryManager, appReviewManager] in
                try await memoryManager.add(item)
                appReviewManager.requestReview()
            }
        case .editItem(let id, let content):
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  case .loaded(let loadedState) = state,
                  var existing = loadedState.items.first(where: { $0.id == id }) else { return }
            existing.content = trimmed
            performMutation { [memoryManager] in try await memoryManager.update(existing) }
        case .toggleItem(let id):
            guard case .loaded(let loadedState) = state,
                  var existing = loadedState.items.first(where: { $0.id == id }) else { return }
            existing.isEnabled.toggle()
            performMutation { [memoryManager] in try await memoryManager.update(existing) }
        case .deleteItem(let id):
            performMutation { [memoryManager] in try await memoryManager.delete(id: id) }
        case .retrySynchronization:
            synchronizeItems()
        }
    }
}

// MARK: - Private

private extension MemoryViewModel {
    func loadItems() {
        let items = memoryManager.getItems().sorted { $0.createdAt > $1.createdAt }
        state = .loaded(LoadedState(items: items))
    }

    func synchronizeItems() {
        guard case .loaded(var loadedState) = state, !loadedState.isSynchronizing else { return }
        loadedState.isSynchronizing = true
        state = .loaded(loadedState)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await memoryManager.synchronize()
                loadItems()
            } catch {
                updateFailure(String(localized: "Memory could not be synchronized. Your local items are retained."))
            }
        }
    }

    func performMutation(_ mutation: @escaping @MainActor () async throws -> Void) {
        Task { [weak self] in
            do {
                try await mutation()
                self?.loadItems()
            } catch {
                self?.updateFailure(String(localized: "The memory change could not be saved. Please try again."))
            }
        }
    }

    func updateFailure(_ message: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.items = memoryManager.getItems().sorted { $0.createdAt > $1.createdAt }
        loadedState.errorMessage = message
        loadedState.isSynchronizing = false
        state = .loaded(loadedState)
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
