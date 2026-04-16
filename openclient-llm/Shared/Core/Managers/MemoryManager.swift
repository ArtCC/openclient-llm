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
/// Local storage is a JSON file in DocumentDirectory and is used when sync is disabled.
///
/// Safety: FileManager operations are thread-safe for different paths. CloudSyncManager
/// operations are file-based and called synchronously on callers' threads.
/// The class is @unchecked Sendable because `metadataQuery` and `queryObserver`
/// are only touched on the main thread during init/deinit.
final class MemoryManager: MemoryManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let legacyItems = "memory_items"
    }

    private static let fileName = "Memory.json"

    /// Notification posted when iCloud pushes an external memory change.
    nonisolated static let memoryDidChangeExternallyNotification = Notification.Name(
        "MemoryManager.memoryDidChangeExternally"
    )

    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    private var localFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.fileName)
    }

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        migrateFromUserDefaultsIfNeeded()
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
        guard let url = localFileURL,
              let data = try? Data(contentsOf: url),
              let items = try? makeDecoder().decode([MemoryItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveToLocal(_ items: [MemoryItem]) {
        guard let url = localFileURL,
              let data = try? makeEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func persist(_ items: [MemoryItem]) {
        saveToLocal(items)
        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.saveMemoryToCloud(items)
        }
    }

    /// One-time migration from the old `memory_items` UserDefaults blob to the
    /// new JSON file in DocumentDirectory.
    func migrateFromUserDefaultsIfNeeded() {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.legacyItems),
           let items = try? makeDecoder().decode([MemoryItem].self, from: data) {
            saveToLocal(items)
            defaults.removeObject(forKey: Keys.legacyItems)
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
