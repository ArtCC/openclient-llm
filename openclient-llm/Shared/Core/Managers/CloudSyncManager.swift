//
//  CloudSyncManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//
import Foundation

nonisolated protocol CloudSyncManagerProtocol: Sendable {
    func isCloudAvailable() -> Bool
    func checkCloudAvailability() async -> Bool
    func loadConversationSyncSnapshot() throws -> ConversationCloudSyncSnapshot
    func validateConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws
    func applyConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws
    func loadProfileSyncSnapshot() async throws -> CloudUserProfileSnapshot
    func applyProfileSyncOutput(
        _ output: CloudUserProfileSyncOutput,
        basedOn snapshot: CloudUserProfileSnapshot
    ) async throws
    func loadTemplatesFromCloud() async throws -> PromptTemplateCloudSnapshot
    func applyTemplateUploads(
        _ templates: [PromptTemplate],
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws
    func applyTemplateDeletion(
        _ marker: CloudDeletionMarker,
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws
    func loadMemorySyncSnapshot() async throws -> MemoryCloudSyncSnapshot
    func applyMemorySyncOutput(
        items: [MemoryItem],
        deletionMarkers: [CloudDeletionMarker],
        basedOn snapshot: MemoryCloudSyncSnapshot
    ) async throws
    func deleteMemoryItemFromCloud(_ itemId: UUID, deletedAt: Date) async throws
    func loadCloudInventory() async -> CloudDataInventory
    func loadCloudPurgeJournal() async throws -> CloudPurgeJournal?
    func deleteCloudData(
        categories: Set<CloudDataCategory>,
        marker: CloudPurgeMarker?
    ) async throws -> CloudDeletionResult
    func loadCloudPurgeMarker() async throws -> CloudPurgeMarker?
    func completeLocalPurgeCleanup(category: CloudDataCategory, marker: CloudPurgeMarker) async throws
}

// Safety: FileManager is thread-safe per Apple documentation. All stored properties are immutable (`let`).
nonisolated struct CloudSyncManager: CloudSyncManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    let fileManager: FileManager
    let containerProvider: CloudContainerProviding
    let fileCoordinator: CloudFileCoordinator
    let categoryOperationGate: CloudCategoryOperationGate
    let mutationGate: CloudSynchronizationMutationGate

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        containerProvider: CloudContainerProviding? = nil,
        fileCoordinator: CloudFileCoordinator = CloudFileCoordinator(),
        categoryOperationGate: CloudCategoryOperationGate = .shared,
        mutationGate: CloudSynchronizationMutationGate = .shared
    ) {
        self.fileManager = fileManager
        self.containerProvider = containerProvider ?? UbiquityCloudContainerProvider(fileManager: fileManager)
        self.fileCoordinator = fileCoordinator
        self.categoryOperationGate = categoryOperationGate
        self.mutationGate = mutationGate
    }

    // MARK: - Public

    func loadTemplatesFromCloud() async throws -> PromptTemplateCloudSnapshot {
        try await categoryOperationGate.perform {
            try await loadTemplateSnapshot()
        }
    }

    func applyTemplateUploads(
        _ templates: [PromptTemplate],
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws {
        try await categoryOperationGate.perform {
            try await applyTemplateSnapshotUploads(templates, basedOn: snapshot)
        }
    }

    func applyTemplateDeletion(
        _ marker: CloudDeletionMarker,
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws {
        try await categoryOperationGate.perform {
            try await applyTemplateSnapshotDeletion(marker, basedOn: snapshot)
        }
    }

    func loadMemorySyncSnapshot() async throws -> MemoryCloudSyncSnapshot {
        try await loadMemorySnapshot()
    }

    func applyMemorySyncOutput(
        items: [MemoryItem],
        deletionMarkers: [CloudDeletionMarker],
        basedOn snapshot: MemoryCloudSyncSnapshot
    ) async throws {
        try await applyMemoryOutput(items: items, deletionMarkers: deletionMarkers, basedOn: snapshot)
    }

    func deleteMemoryItemFromCloud(_ itemId: UUID, deletedAt: Date) async throws {
        try await mutateCategory { manager, documentsURL in
            var markers = try manager.loadMemoryDeletionMarkers(in: documentsURL)
            let marker = CloudDeletionMarker(id: itemId, deletedAt: deletedAt)
            if let index = markers.firstIndex(where: { $0.id == itemId }) {
                if markers[index].deletedAt < deletedAt { markers[index] = marker }
            } else {
                markers.append(marker)
            }
            markers.sort { $0.id.uuidString < $1.id.uuidString }
            let markersURL = documentsURL.appendingPathComponent("MemoryTombstones.json")
            try manager.writeMemoryValue(markers, to: markersURL)
            let memoryURL = documentsURL.appendingPathComponent("Memory.json")
            if var items = try manager.decodeIfPresent([MemoryItem].self, at: memoryURL) {
                let effectiveDeletionDate = markers.first { $0.id == itemId }?.deletedAt ?? deletedAt
                items.removeAll { $0.id == itemId && $0.updatedAt <= effectiveDeletionDate }
                try manager.writeMemoryValue(items, to: memoryURL)
            }
        }
    }

}

// MARK: - Memory

extension CloudSyncManager {
    func writeMemoryValue<Value: Codable>(_ value: Value, to url: URL) throws {
        let encoder = SyncJSONCoding.makeEncoder()
        let data = try encoder.encode(value)
        if fileManager.fileExists(atPath: url.path), try Data(contentsOf: url) == data { return }
        try ensureDirectoryExists(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
        let writtenData = try Data(contentsOf: url)
        guard writtenData == data else { throw CloudSyncError.cloudContentChanged }
        let decoded = try SyncJSONCoding.makeDecoder().decode(Value.self, from: writtenData)
        guard try encoder.encode(decoded) == data else { throw CloudSyncError.cloudContentChanged }
    }
}
