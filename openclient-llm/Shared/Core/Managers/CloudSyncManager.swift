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
    func saveProfileToCloud(_ profile: UserProfile) async throws
    func loadProfileStateFromCloud() async throws -> CloudUserProfileState
    func loadProfileFromCloud() async throws -> UserProfile?
    func deleteProfileFromCloud() async throws
    func syncTemplatesToCloud(_ templates: [PromptTemplate]) async throws
    func loadTemplatesFromCloud() async throws -> PromptTemplateCloudSnapshot
    func deleteTemplateFromCloud(_ templateId: UUID, deletedAt: Date) async throws
    func saveMemoryToCloud(_ items: [MemoryItem]) async throws
    func loadMemorySyncSnapshot() async throws -> MemoryCloudSyncSnapshot
    func deleteMemoryItemFromCloud(_ itemId: UUID, deletedAt: Date) async throws
}

// Safety: FileManager is thread-safe per Apple documentation. All stored properties are immutable (`let`).
nonisolated struct CloudSyncManager: CloudSyncManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    let fileManager: FileManager
    let containerProvider: CloudContainerProviding
    let fileCoordinator: CloudFileCoordinator
    let categoryOperationGate: CloudCategoryOperationGate

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        containerProvider: CloudContainerProviding? = nil,
        fileCoordinator: CloudFileCoordinator = CloudFileCoordinator(),
        categoryOperationGate: CloudCategoryOperationGate = .shared
    ) {
        self.fileManager = fileManager
        self.containerProvider = containerProvider ?? UbiquityCloudContainerProvider(fileManager: fileManager)
        self.fileCoordinator = fileCoordinator
        self.categoryOperationGate = categoryOperationGate
    }

    // MARK: - Public

    func saveProfileToCloud(_ profile: UserProfile) async throws {
        try await categoryOperationGate.perform {
            try await mutateCategory { manager, documentsURL in
                let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
                let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
                let existingProfile = try manager.decodeIfPresent(UserProfile.self, at: profileURL)
                let marker = try manager.decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
                if let marker, profile.modifiedAt <= marker.deletedAt {
                    throw CloudSyncError.staleProfileRevision
                }
                if let existingProfile {
                    guard existingProfile.modifiedAt <= profile.modifiedAt else {
                        throw CloudSyncError.staleProfileRevision
                    }
                    if existingProfile.modifiedAt == profile.modifiedAt, existingProfile != profile {
                        throw CloudSyncError.conflictingProfileRevision
                    }
                }
                try manager.writeEncoded(profile, to: profileURL)
                try manager.removeCategoryItemIfPresent(at: markerURL)
            }
        }
    }

    func loadProfileStateFromCloud() async throws -> CloudUserProfileState {
        try await categoryOperationGate.perform {
            try await readCategory { manager, documentsURL in
                try manager.loadProfileState(in: documentsURL)
            }
        }
    }

    func loadProfileFromCloud() async throws -> UserProfile? {
        switch try await loadProfileStateFromCloud() {
        case .missing, .deleted:
            nil
        case .profile(let profile):
            profile
        }
    }

    func deleteProfileFromCloud() async throws {
        try await categoryOperationGate.perform {
            try await mutateCategory { manager, documentsURL in
                let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
                let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
                let existingProfile = try manager.decodeIfPresent(UserProfile.self, at: profileURL)
                let existingMarker = try manager.decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
                guard existingProfile != nil || existingMarker == nil else { return }
                let profileRevision = existingProfile?.modifiedAt.addingTimeInterval(0.001) ?? .distantPast
                let deletedAt = max(Date(), max(profileRevision, existingMarker?.deletedAt ?? .distantPast))
                let marker = CloudDeletionMarker(id: Self.profileMarkerId, deletedAt: deletedAt)
                try manager.writeEncoded(marker, to: markerURL)
                try manager.removeCategoryItemIfPresent(at: profileURL)
            }
        }
    }

    func syncTemplatesToCloud(_ templates: [PromptTemplate]) async throws {
        try await categoryOperationGate.perform {
            try await mutateCategory { manager, documentsURL in
                let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
                try manager.ensureDirectoryExists(at: directory)
                let markers = try manager.loadTemplateDeletionMarkers(in: documentsURL)
                for template in templates {
                    let templateURL = directory.appendingPathComponent("\(template.id.uuidString).json")
                    if let marker = markers[template.id], template.updatedAt <= marker.deletedAt {
                        if let existing = try manager.decodeIfPresent(PromptTemplate.self, at: templateURL),
                           existing.updatedAt > marker.deletedAt {
                            continue
                        }
                        try manager.removeCategoryItemIfPresent(at: templateURL)
                        continue
                    }
                    try manager.writeEncoded(template, to: templateURL)
                    let markerURL = documentsURL.appendingPathComponent(
                        "PromptTemplateTombstones/\(template.id.uuidString).json"
                    )
                    try manager.removeCategoryItemIfPresent(at: markerURL)
                }
            }
        }
    }

    func loadTemplatesFromCloud() async throws -> PromptTemplateCloudSnapshot {
        try await categoryOperationGate.perform {
            try await readCategory { manager, documentsURL in
                let deletionMarkers = try manager.loadTemplateDeletionMarkers(in: documentsURL)
                let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
                guard manager.fileManager.fileExists(atPath: directory.path) else {
                    return PromptTemplateCloudSnapshot(
                        templates: [],
                        templateData: [:],
                        deletionMarkers: deletionMarkers
                    )
                }
                let urls = try manager.categoryContents(of: directory)
                var templates: [PromptTemplate] = []
                var templateData: [UUID: Data] = [:]
                for url in urls {
                    guard url.pathExtension == "json",
                          let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
                    try manager.requireCategoryFileReady(at: url)
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let template = try decoder.decode(PromptTemplate.self, from: data)
                    guard template.id == id else { continue }
                    if let marker = deletionMarkers[id], template.updatedAt <= marker.deletedAt { continue }
                    templates.append(template)
                    templateData[id] = data
                }
                return PromptTemplateCloudSnapshot(
                    templates: templates,
                    templateData: templateData,
                    deletionMarkers: deletionMarkers
                )
            }
        }
    }

    func deleteTemplateFromCloud(_ templateId: UUID, deletedAt: Date) async throws {
        try await categoryOperationGate.perform {
            try await mutateCategory { manager, documentsURL in
                let markerDirectory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
                try manager.ensureDirectoryExists(at: markerDirectory)
                let markerURL = markerDirectory.appendingPathComponent("\(templateId.uuidString).json")
                let existingMarker = try manager.decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
                let marker = existingMarker.map { existing in
                    existing.deletedAt >= deletedAt
                        ? existing
                        : CloudDeletionMarker(id: templateId, deletedAt: deletedAt)
                } ?? CloudDeletionMarker(id: templateId, deletedAt: deletedAt)
                try manager.writeEncoded(marker, to: markerURL)
                let payload = documentsURL.appendingPathComponent("PromptTemplates/\(templateId.uuidString).json")
                if let template = try manager.decodeIfPresent(PromptTemplate.self, at: payload),
                   template.updatedAt > marker.deletedAt {
                    return
                }
                try manager.removeCategoryItemIfPresent(at: payload)
            }
        }
    }

    func saveMemoryToCloud(_ items: [MemoryItem]) async throws {
        try await mutateCategory { manager, documentsURL in
            let markers = try manager.loadMemoryDeletionMarkers(in: documentsURL)
            let markerById = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
            let survivors = items.filter { item in
                guard let marker = markerById[item.id] else { return true }
                return item.updatedAt > marker.deletedAt
            }.sorted { $0.id.uuidString < $1.id.uuidString }
            try manager.writeMemoryValue(survivors, to: documentsURL.appendingPathComponent("Memory.json"))
        }
    }

    func loadMemorySyncSnapshot() async throws -> MemoryCloudSyncSnapshot {
        try await readCategory { manager, documentsURL in
            let markers = try manager.loadMemoryDeletionMarkers(in: documentsURL)
            let url = documentsURL.appendingPathComponent("Memory.json")
            let items = try manager.decodeIfPresent([MemoryItem].self, at: url)
            let markerById = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
            let eligibleItems = items?.filter { item in
                guard let marker = markerById[item.id] else { return true }
                return item.updatedAt > marker.deletedAt
            }
            return MemoryCloudSyncSnapshot(items: eligibleItems, deletionMarkers: markers)
        }
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

private extension CloudSyncManager {
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

// MARK: - Prompt Templates

private extension CloudSyncManager {
    func loadTemplateDeletionMarkers(in documentsURL: URL) throws -> [UUID: CloudDeletionMarker] {
        let directory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return [:] }
        let markers = try categoryContents(of: directory).compactMap { url -> CloudDeletionMarker? in
            guard url.pathExtension == "json" else { return nil }
            return try decode(CloudDeletionMarker.self, at: url)
        }
        return markers.reduce(into: [:]) { result, marker in
            if result[marker.id]?.deletedAt ?? .distantPast < marker.deletedAt {
                result[marker.id] = marker
            }
        }
    }
}
