//
//  MemoryManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol MemoryManagerProtocol: Sendable {
    func getItems() -> [MemoryItem]
    func add(_ item: MemoryItem)
    func update(_ item: MemoryItem)
    func delete(id: UUID)
    func deleteAll()
}

/// Manages the persistent memory list with optional iCloud sync.
///
/// When iCloud sync is enabled the cloud `Memory.json` is the single source of truth.
/// Local UserDefaults acts as a cache and is used when sync is disabled.
///
/// Safety: UserDefaults is thread-safe per Apple documentation. CloudSyncManager
/// operations are file-based and called synchronously on callers' threads.
/// The class is @unchecked Sendable because `metadataQuery` and `queryObserver`
/// are only touched on the main thread during init/deinit.
final class MemoryManager: MemoryManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let items = "memory_items"
    }

    /// Notification posted when iCloud pushes an external memory change.
    nonisolated static let memoryDidChangeExternallyNotification = Notification.Name(
        "MemoryManager.memoryDidChangeExternally"
    )

    private let defaults: UserDefaults
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        defaults: UserDefaults = .standard,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.defaults = defaults
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        startMonitoringCloudFile()
    }

    deinit {
        metadataQuery?.stop()
        if let queryObserver {
            NotificationCenter.default.removeObserver(queryObserver)
        }
    }

    // MARK: - Public

    func getItems() -> [MemoryItem] {
        if settingsManager.getIsCloudSyncEnabled() {
            if let cloudItems = try? cloudSyncManager.loadMemoryFromCloud() {
                saveToLocal(cloudItems)
                return cloudItems
            }
        }
        return loadFromLocal()
    }

    func add(_ item: MemoryItem) {
        var items = getItems()
        items.append(item)
        persist(items)
    }

    func update(_ item: MemoryItem) {
        var items = getItems()
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        persist(items)
    }

    func delete(id: UUID) {
        var items = getItems()
        items.removeAll { $0.id == id }
        persist(items)
    }

    func deleteAll() {
        persist([])
        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.deleteMemoryFromCloud()
        }
    }
}

// MARK: - Private

private extension MemoryManager {
    func loadFromLocal() -> [MemoryItem] {
        guard let data = defaults.data(forKey: Keys.items),
              let items = try? makeDecoder().decode([MemoryItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveToLocal(_ items: [MemoryItem]) {
        guard let data = try? makeEncoder().encode(items) else { return }
        defaults.set(data, forKey: Keys.items)
    }

    func persist(_ items: [MemoryItem]) {
        saveToLocal(items)
        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.saveMemoryToCloud(items)
        }
    }

    func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func startMonitoringCloudFile() {
        guard cloudSyncManager.isCloudAvailable() else { return }

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "Memory.json")
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        let settingsManager = self.settingsManager
        queryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                guard settingsManager.getIsCloudSyncEnabled() else { return }
                NotificationCenter.default.post(
                    name: MemoryManager.memoryDidChangeExternallyNotification,
                    object: nil
                )
            }
        }

        metadataQuery = query
        query.start()
    }
}
