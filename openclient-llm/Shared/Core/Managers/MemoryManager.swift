//
//  MemoryManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct MemoryCloudSyncSnapshot: Sendable {
    let items: [MemoryItem]?
    let deletionMarkers: [CloudDeletionMarker]
}

protocol MemoryManagerProtocol: Sendable {
    func getItems() -> [MemoryItem]
    func synchronize() async throws
    func add(_ item: MemoryItem) async throws
    func update(_ item: MemoryItem) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

/// Manages the persistent memory list with optional iCloud sync.
///
/// Local and cloud records are reconciled by ID and revision when iCloud sync is enabled.
///
/// Safety: FileManager operations are thread-safe for different paths. Cloud operations are async.
/// `metadataQuery` and `queryObserver` are touched only on the main actor.
final class MemoryManager: MemoryManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let legacyItems = "memory_items"
    }

    private static let fileName = "Memory.json"
    private static let deletionFileName = "MemoryTombstones.json"
    private static let recoveryFileName = "MemoryRecovery.json"

    /// Notification posted when iCloud pushes an external memory change.
    nonisolated static let memoryDidChangeExternallyNotification = Notification.Name(
        "MemoryManager.memoryDidChangeExternally"
    )

    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let categoryOperationGate: CloudCategoryOperationGate
    private let userDefaults: UserDefaults
    private let localFileURL: URL?
    private let localDeletionFileURL: URL?
    private let localRecoveryFileURL: URL?
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        documentsURL: URL? = nil,
        userDefaults: UserDefaults = .standard,
        categoryOperationGate: CloudCategoryOperationGate = .shared
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.categoryOperationGate = categoryOperationGate
        self.userDefaults = userDefaults
        let resolvedDocumentsURL = documentsURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.localFileURL = resolvedDocumentsURL?.appendingPathComponent(Self.fileName)
        self.localDeletionFileURL = resolvedDocumentsURL?.appendingPathComponent(Self.deletionFileName)
        self.localRecoveryFileURL = resolvedDocumentsURL?.appendingPathComponent(Self.recoveryFileName)
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
        let items = (try? loadItemsForDisplay()) ?? []
        let markers = (try? loadDeletionMarkers()) ?? []
        return applying(markers, to: items)
    }

    func synchronize() async throws {
        guard settingsManager.getIsCloudSyncEnabled() else { return }
        try await performSerializedIfNeeded { [self] in
            try migrateFromUserDefaultsIfNeeded()
            try await reconcile(localItems: loadFromLocal())
        }
    }

    func add(_ item: MemoryItem) async throws {
        try await performSerializedIfNeeded { [self] in
            try await addItem(item)
        }
    }

    func update(_ item: MemoryItem) async throws {
        try await performSerializedIfNeeded { [self] in
            try await updateItem(item)
        }
    }

    func delete(id: UUID) async throws {
        try await performSerializedIfNeeded { [self] in
            try await deleteItem(id: id)
        }
    }

    func deleteAll() async throws {
        try await performSerializedIfNeeded { [self] in
            try await deleteAllItems()
        }
    }
}

// MARK: - Private

private extension MemoryManager {
    struct MergeResult {
        let items: [MemoryItem]
        let losingItems: [MemoryItem]
    }

    func addItem(_ item: MemoryItem) async throws {
        try migrateFromUserDefaultsIfNeeded()
        var newItem = item
        let markers = try loadDeletionMarkers()
        if let marker = markers.first(where: { $0.id == item.id }), newItem.updatedAt <= marker.deletedAt {
            newItem.updatedAt = nextRevision(after: marker.deletedAt)
        }
        var items = applying(markers, to: try loadFromLocal())
        items.removeAll { $0.id == newItem.id }
        items.append(newItem)
        try await persist(items)
    }

    func updateItem(_ item: MemoryItem) async throws {
        try migrateFromUserDefaultsIfNeeded()
        let markers = try loadDeletionMarkers()
        var items = applying(markers, to: try loadFromLocal())
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var revisedItem = item
        revisedItem.updatedAt = nextRevision(after: items[index].updatedAt)
        items[index] = revisedItem
        try await persist(items)
    }

    func deleteItem(id: UUID) async throws {
        try migrateFromUserDefaultsIfNeeded()
        let items = try loadFromLocal()
        var markers = try loadDeletionMarkers()
        var relevantItems = items.filter { $0.id == id }
        if settingsManager.getIsCloudSyncEnabled() {
            let snapshot = try await cloudSyncManager.loadMemorySyncSnapshot()
            markers = mergeDeletionMarkers(markers, snapshot.deletionMarkers)
            relevantItems += (snapshot.items ?? []).filter { $0.id == id }
        }
        let newestRevision = relevantItems.map(\.updatedAt).max() ?? Date()
        let deletionFloor = max(newestRevision, markers.first { $0.id == id }?.deletedAt ?? .distantPast)
        let marker = CloudDeletionMarker(id: id, deletedAt: nextRevision(after: deletionFloor))
        markers = mergeDeletionMarkers(markers, [marker])
        try saveDeletionMarkers(markers)
        try saveToLocal(items.filter { $0.id != id })
        if settingsManager.getIsCloudSyncEnabled() {
            try await cloudSyncManager.deleteMemoryItemFromCloud(id, deletedAt: marker.deletedAt)
        }
    }

    func deleteAllItems() async throws {
        try migrateFromUserDefaultsIfNeeded()
        let items = try loadFromLocal()
        var allItems = items
        var markers = try loadDeletionMarkers()
        if settingsManager.getIsCloudSyncEnabled() {
            let snapshot = try await cloudSyncManager.loadMemorySyncSnapshot()
            allItems += snapshot.items ?? []
            markers = mergeDeletionMarkers(markers, snapshot.deletionMarkers)
        }
        let deletionFloor = max(
            allItems.map(\.updatedAt).max() ?? Date(),
            markers.map(\.deletedAt).max() ?? .distantPast
        )
        let deletedAt = nextRevision(after: deletionFloor)
        let newMarkers = Set(allItems.map(\.id)).map { CloudDeletionMarker(id: $0, deletedAt: deletedAt) }
        markers = mergeDeletionMarkers(markers, newMarkers)
        try saveDeletionMarkers(markers)
        try saveToLocal([])
        guard settingsManager.getIsCloudSyncEnabled() else { return }
        try await retryCloudDeletions()
    }

    func performSerializedIfNeeded(
        _ operation: @escaping @MainActor @Sendable () async throws -> Void
    ) async throws {
        if settingsManager.getIsCloudSyncEnabled() {
            try await categoryOperationGate.perform {
                try await operation()
            }
        } else {
            try await operation()
        }
    }

    func loadItemsForDisplay() throws -> [MemoryItem] {
        if let url = localFileURL, FileManager.default.fileExists(atPath: url.path) {
            return try loadFromLocal()
        }
        guard let data = userDefaults.data(forKey: Keys.legacyItems) else { return [] }
        return try makeDecoder().decode([MemoryItem].self, from: data)
    }

    func loadFromLocal() throws -> [MemoryItem] {
        try decodeIfPresent([MemoryItem].self, at: localFileURL) ?? []
    }

    func saveToLocal(_ items: [MemoryItem]) throws {
        try writeAndValidate(items.sorted(by: itemSort), to: localFileURL)
    }

    func persist(_ items: [MemoryItem]) async throws {
        if settingsManager.getIsCloudSyncEnabled() {
            try await reconcile(localItems: items)
        } else {
            try saveToLocal(items)
        }
    }

    func reconcile(localItems: [MemoryItem]) async throws {
        let snapshot = try await cloudSyncManager.loadMemorySyncSnapshot()
        let markers = mergeDeletionMarkers(try loadDeletionMarkers(), snapshot.deletionMarkers)
        let merge = try mergeItems(
            local: localItems,
            cloud: snapshot.items ?? [],
            deletionMarkers: markers
        )
        try preserveForRecovery(merge.losingItems)
        try saveDeletionMarkers(markers)
        try saveToLocal(merge.items)
        for marker in markers {
            try await cloudSyncManager.deleteMemoryItemFromCloud(marker.id, deletedAt: marker.deletedAt)
        }
        try await cloudSyncManager.saveMemoryToCloud(merge.items)
    }

    func loadDeletionMarkers() throws -> [CloudDeletionMarker] {
        let markers = try decodeIfPresent([CloudDeletionMarker].self, at: localDeletionFileURL) ?? []
        return mergeDeletionMarkers(markers, [])
    }

    func saveDeletionMarkers(_ markers: [CloudDeletionMarker]) throws {
        try writeAndValidate(markers.sorted { $0.id.uuidString < $1.id.uuidString }, to: localDeletionFileURL)
    }

    func retryCloudDeletions() async throws {
        for marker in try loadDeletionMarkers() {
            try await cloudSyncManager.deleteMemoryItemFromCloud(marker.id, deletedAt: marker.deletedAt)
        }
    }

    /// One-time migration from the old `memory_items` UserDefaults blob to the
    /// new JSON file in DocumentDirectory.
    func migrateFromUserDefaultsIfNeeded() throws {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = userDefaults.data(forKey: Keys.legacyItems) else { return }
        let items = try makeDecoder().decode([MemoryItem].self, from: data)
        try saveToLocal(items)
        userDefaults.removeObject(forKey: Keys.legacyItems)
    }

    func applying(_ markers: [CloudDeletionMarker], to items: [MemoryItem]) -> [MemoryItem] {
        let markerById = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
        return items.filter { item in
            guard let marker = markerById[item.id] else { return true }
            return item.updatedAt > marker.deletedAt
        }
    }

    func mergeDeletionMarkers(
        _ local: [CloudDeletionMarker],
        _ cloud: [CloudDeletionMarker]
    ) -> [CloudDeletionMarker] {
        var merged: [UUID: CloudDeletionMarker] = [:]
        for marker in local + cloud {
            if let current = merged[marker.id], current.deletedAt >= marker.deletedAt { continue }
            merged[marker.id] = marker
        }
        return merged.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func mergeItems(
        local: [MemoryItem],
        cloud: [MemoryItem],
        deletionMarkers: [CloudDeletionMarker]
    ) throws -> MergeResult {
        var winners: [UUID: MemoryItem] = [:]
        var losingItems: [MemoryItem] = []

        for candidate in applying(deletionMarkers, to: local + cloud) {
            guard let current = winners[candidate.id] else {
                winners[candidate.id] = candidate
                continue
            }
            guard current != candidate else { continue }
            if try isPreferred(candidate, over: current) {
                losingItems.append(current)
                winners[candidate.id] = candidate
            } else {
                losingItems.append(candidate)
            }
        }

        return MergeResult(
            items: winners.values.sorted(by: itemSort),
            losingItems: losingItems.sorted(by: recoverySort)
        )
    }

    func isPreferred(_ candidate: MemoryItem, over current: MemoryItem) throws -> Bool {
        if candidate.updatedAt != current.updatedAt { return candidate.updatedAt > current.updatedAt }
        let candidateData = try makeEncoder().encode(candidate)
        let currentData = try makeEncoder().encode(current)
        return currentData.lexicographicallyPrecedes(candidateData)
    }

    func preserveForRecovery(_ items: [MemoryItem]) throws {
        guard !items.isEmpty else { return }
        var recoveryItems = try decodeIfPresent([MemoryItem].self, at: localRecoveryFileURL) ?? []
        for item in items where !recoveryItems.contains(item) {
            recoveryItems.append(item)
        }
        try writeAndValidate(recoveryItems.sorted(by: recoverySort), to: localRecoveryFileURL)
    }

    func decodeIfPresent<Value: Decodable>(_ type: Value.Type, at url: URL?) throws -> Value? {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try makeDecoder().decode(type, from: Data(contentsOf: url))
    }

    func writeAndValidate<Value: Codable>(_ value: Value, to url: URL?) throws {
        guard let url else { throw CocoaError(.fileWriteUnknown) }
        let data = try makeEncoder().encode(value)
        if FileManager.default.fileExists(atPath: url.path), try Data(contentsOf: url) == data { return }
        try data.write(to: url, options: .atomic)
        let writtenData = try Data(contentsOf: url)
        guard writtenData == data else { throw CocoaError(.fileWriteUnknown) }
        let decoded = try makeDecoder().decode(Value.self, from: writtenData)
        guard try makeEncoder().encode(decoded) == data else { throw CocoaError(.fileWriteUnknown) }
    }

    func nextRevision(after revision: Date) -> Date {
        let now = Date()
        return max(now, revision.addingTimeInterval(1))
    }

    func itemSort(_ lhs: MemoryItem, _ rhs: MemoryItem) -> Bool {
        lhs.id.uuidString < rhs.id.uuidString
    }

    func recoverySort(_ lhs: MemoryItem, _ rhs: MemoryItem) -> Bool {
        if lhs.id != rhs.id { return lhs.id.uuidString < rhs.id.uuidString }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        if lhs.content != rhs.content { return lhs.content < rhs.content }
        if lhs.isEnabled != rhs.isEnabled { return !lhs.isEnabled }
        return lhs.source.rawValue < rhs.source.rawValue
    }

    func makeEncoder() -> JSONEncoder {
        SyncJSONCoding.makeEncoder()
    }

    func makeDecoder() -> JSONDecoder {
        SyncJSONCoding.makeDecoder()
    }

    func startMonitoringCloudFile() {
        guard settingsManager.getIsCloudSyncEnabled() else { return }
        Task { [weak self] in
            guard let self, await cloudSyncManager.checkCloudAvailability() else { return }
            beginMonitoringCloudFile()
        }
    }

    func beginMonitoringCloudFile() {
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
