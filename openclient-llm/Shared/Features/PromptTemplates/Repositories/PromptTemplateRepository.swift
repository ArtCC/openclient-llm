//
//  PromptTemplateRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol PromptTemplateRepositoryProtocol: Sendable {
    func loadAll() async throws -> [PromptTemplate]
    func save(_ template: PromptTemplate) async throws
    func delete(_ templateId: UUID) async throws
    func deleteSynchronized(_ templateId: UUID) async throws
    func deleteAllLocal() async throws
    func purgeLocalData(through marker: CloudPurgeMarker) async throws
    func validateLocalReset() async throws
}

struct PromptTemplateRepository: PromptTemplateRepositoryProtocol {
    // MARK: - Properties

    let fileManager: FileManager
    let directoryURL: URL
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let mutationGate: CloudSynchronizationMutationGate
    let operationGate: PromptTemplateOperationGate

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        directoryURL: URL? = nil,
        mutationGate: CloudSynchronizationMutationGate = .shared,
        operationGate: PromptTemplateOperationGate = .shared
    ) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = directoryURL
            ?? documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.mutationGate = mutationGate
        self.operationGate = operationGate
    }

    // MARK: - Public

    func loadAll() async throws -> [PromptTemplate] {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        return try await performSerialized(requiredCloudIntent: requiredCloudIntent) {
            try await loadAllSerialized(requiredCloudIntent: requiredCloudIntent)
        }
    }

    func save(_ template: PromptTemplate) async throws {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        try await performSerialized(requiredCloudIntent: requiredCloudIntent) {
            try await saveSerialized(template, requiredCloudIntent: requiredCloudIntent)
        }
    }

    func delete(_ templateId: UUID) async throws {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        try await performSerialized(requiredCloudIntent: requiredCloudIntent) {
            try await deleteSerialized(templateId, requiredCloudIntent: requiredCloudIntent)
        }
    }

    func deleteSynchronized(_ templateId: UUID) async throws {
        guard settingsManager.getIsCloudSyncEnabled() else {
            throw CloudDataManagementError.cloudSyncDisabled
        }
        try await performSerialized(requiredCloudIntent: true) {
            try await deleteSerialized(templateId, requiredCloudIntent: true)
        }
    }

    private func loadAllSerialized(requiredCloudIntent: Bool) async throws -> [PromptTemplate] {
        try checkOperationIntent(requiredCloudIntent)
        LogManager.debug("loadAll prompt templates")
        try ensureDirectoryExists()

        var deletionMarkers = try loadDeletionMarkers()
        let localTemplates = try loadCustomTemplates()
        var mergedTemplates = localTemplates.filter { shouldKeep($0.template, markers: deletionMarkers) }

        if requiredCloudIntent {
            var snapshot = try await cloudSyncManager.loadTemplatesFromCloud()
            try checkOperationIntent(requiredCloudIntent)
            deletionMarkers = mergeDeletionMarkers(local: deletionMarkers, cloud: snapshot.deletionMarkers)
            deletionMarkers = applying(snapshot.purgeMarker, to: deletionMarkers, templates: localTemplates)
            try saveDeletionMarkers(deletionMarkers)
            snapshot = try await synchronizeDeletionMarkers(deletionMarkers, snapshot: snapshot)
            let cloudTemplates = try storedCloudTemplates(snapshot)
            mergedTemplates = try mergeTemplates(
                local: localTemplates,
                cloud: cloudTemplates,
                markers: deletionMarkers
            )
            try checkOperationIntent(requiredCloudIntent)
            try persistLocalOutput(mergedTemplates)
            let uploads = templatesNeedingCloudWrite(
                mergedTemplates,
                cloud: cloudTemplates
            )
            try await writeAndVerifyCloudTemplates(uploads, basedOn: snapshot)
        } else {
            try checkOperationIntent(requiredCloudIntent)
            try persistLocalOutput(mergedTemplates)
        }

        let customTemplates = mergedTemplates.map(\.template).sorted { $0.createdAt < $1.createdAt }
        let all = builtIns() + customTemplates
        LogManager.success("loadAll returned \(all.count) prompt templates")
        return all
    }

    private func saveSerialized(_ template: PromptTemplate, requiredCloudIntent: Bool) async throws {
        try checkOperationIntent(requiredCloudIntent)
        LogManager.debug("save prompt template id=\(template.id) title='\(template.title)'")
        guard !template.isBuiltIn else { return }
        try ensureDirectoryExists()

        let localTemplates = try loadCustomTemplates()
        var deletionMarkers = try loadDeletionMarkers()
        var cloudTemplates: [StoredTemplate] = []
        var cloudSnapshot: PromptTemplateCloudSnapshot?
        if requiredCloudIntent {
            var snapshot = try await cloudSyncManager.loadTemplatesFromCloud()
            try checkOperationIntent(requiredCloudIntent)
            deletionMarkers = mergeDeletionMarkers(local: deletionMarkers, cloud: snapshot.deletionMarkers)
            deletionMarkers = applying(snapshot.purgeMarker, to: deletionMarkers, templates: localTemplates)
            try saveDeletionMarkers(deletionMarkers)
            snapshot = try await synchronizeDeletionMarkers(deletionMarkers, snapshot: snapshot)
            cloudTemplates = try storedCloudTemplates(snapshot)
            cloudSnapshot = snapshot
        }

        let current = try mergeTemplates(local: localTemplates, cloud: cloudTemplates, markers: deletionMarkers)
            .first { $0.template.id == template.id }
        if let current, !hasSameContent(current.template, template) {
            try preserveForRecovery(current)
        }
        let revisionFloor = [
            template.updatedAt,
            current?.template.updatedAt ?? .distantPast,
            deletionMarkers[template.id]?.deletedAt ?? .distantPast,
            cloudSnapshot?.purgeMarker?.deletedAt ?? .distantPast
        ].max() ?? template.updatedAt
        let revisedTemplate = try canonicalTemplate(templateWithRevision(template, after: revisionFloor))
        try checkOperationIntent(requiredCloudIntent)
        try saveLocal(revisedTemplate)

        if requiredCloudIntent {
            guard let cloudSnapshot else { throw CloudSyncError.cloudContentChanged }
            try await writeAndVerifyCloudTemplates([revisedTemplate], basedOn: cloudSnapshot)
        }

        LogManager.success("saved prompt template id=\(revisedTemplate.id)")
    }

    private func deleteSerialized(_ templateId: UUID, requiredCloudIntent: Bool) async throws {
        try checkOperationIntent(requiredCloudIntent)
        LogManager.debug("delete prompt template id=\(templateId)")
        try ensureDirectoryExists()
        let localTemplates = try loadCustomTemplates()
        var markers = try loadDeletionMarkers()
        var cloudRevision = Date.distantPast
        var cloudSnapshot: PromptTemplateCloudSnapshot?

        if requiredCloudIntent {
            let snapshot = try await cloudSyncManager.loadTemplatesFromCloud()
            try checkOperationIntent(requiredCloudIntent)
            _ = try storedCloudTemplates(snapshot)
            markers = mergeDeletionMarkers(local: markers, cloud: snapshot.deletionMarkers)
            try saveDeletionMarkers(markers)
            cloudRevision = snapshot.rawTemplates[templateId]?.updatedAt ?? .distantPast
            cloudSnapshot = snapshot
        }

        let fileURL = directoryURL.appendingPathComponent("\(templateId.uuidString).json")
        let localRevision = localTemplates.first { $0.template.id == templateId }?.template.updatedAt ?? .distantPast
        let markerRevision = markers[templateId]?.deletedAt ?? .distantPast
        let hasPayload = localRevision != .distantPast || cloudRevision != .distantPast
        if !hasPayload, markerRevision != .distantPast {
            guard let marker = markers[templateId] else {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            guard let cloudSnapshot,
                  (cloudSnapshot.deletionMarkers[templateId]?.deletedAt ?? .distantPast) < markerRevision else {
                return
            }
            _ = try await applyDeletionWithRetry(marker, basedOn: cloudSnapshot)
            return
        }
        let deletionFloor = max(max(localRevision, cloudRevision), markerRevision)
        let deletedAt = nextRevision(after: deletionFloor)
        let marker = CloudDeletionMarker(id: templateId, deletedAt: deletedAt)
        try checkOperationIntent(requiredCloudIntent)
        try saveDeletionMarker(marker)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        LogManager.success("deleted prompt template id=\(templateId)")

        if requiredCloudIntent {
            guard let cloudSnapshot else { throw CloudSyncError.cloudContentChanged }
            _ = try await applyDeletionWithRetry(marker, basedOn: cloudSnapshot)
        }
    }
}

// MARK: - Private

private extension PromptTemplateRepository {
    func performSerialized<Value: Sendable>(
        requiredCloudIntent: Bool,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        guard requiredCloudIntent else { return try await operationGate.perform(operation) }
        return try await mutationGate.perform {
            try await self.checkOperationIntent(requiredCloudIntent)
            return try await operationGate.perform {
                try self.checkOperationIntent(requiredCloudIntent)
                return try await operation()
            }
        }
    }

    func synchronizeDeletionMarkers(
        _ markers: [UUID: CloudDeletionMarker],
        snapshot: PromptTemplateCloudSnapshot
    ) async throws -> PromptTemplateCloudSnapshot {
        let pendingMarkerIDs = Set(markers.values.compactMap { marker in
            (snapshot.deletionMarkers[marker.id]?.deletedAt ?? .distantPast) < marker.deletedAt
                ? marker.id
                : nil
        })
        let ids = pendingMarkerIDs.union(snapshot.staleTemplateIds).sorted { $0.uuidString < $1.uuidString }
        var currentSnapshot = snapshot
        for id in ids {
            guard let marker = markers[id] else {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            currentSnapshot = try await applyDeletionWithRetry(marker, basedOn: currentSnapshot)
        }
        return currentSnapshot
    }

    func applyDeletionWithRetry(
        _ marker: CloudDeletionMarker,
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws -> PromptTemplateCloudSnapshot {
        do {
            try await cloudSyncManager.applyTemplateDeletion(marker, basedOn: snapshot)
        } catch let error as CloudSyncError where error == .cloudContentChanged {
            let refreshed = try await cloudSyncManager.loadTemplatesFromCloud()
            _ = try storedCloudTemplates(refreshed)
            try await cloudSyncManager.applyTemplateDeletion(marker, basedOn: refreshed)
        }
        let current = try await cloudSyncManager.loadTemplatesFromCloud()
        _ = try storedCloudTemplates(current)
        guard (current.deletionMarkers[marker.id]?.deletedAt ?? .distantPast) >= marker.deletedAt,
              !current.staleTemplateIds.contains(marker.id) else {
            throw CloudSyncError.cloudContentChanged
        }
        return current
    }

    func mergeTemplates(
        local: [StoredTemplate],
        cloud: [StoredTemplate],
        markers: [UUID: CloudDeletionMarker]
    ) throws -> [StoredTemplate] {
        let localById = Dictionary(uniqueKeysWithValues: local.map { ($0.template.id, $0) })
        let cloudById = Dictionary(uniqueKeysWithValues: cloud.map { ($0.template.id, $0) })
        let ids = Set(localById.keys).union(cloudById.keys).sorted { $0.uuidString < $1.uuidString }
        return try ids.compactMap { id in
            let localCandidate = localById[id].flatMap {
                shouldKeep($0.template, markers: markers) ? $0 : nil
            }
            let cloudCandidate = cloudById[id].flatMap {
                shouldKeep($0.template, markers: markers) ? $0 : nil
            }
            guard let localCandidate, let cloudCandidate else {
                return localCandidate ?? cloudCandidate
            }
            guard localCandidate.template != cloudCandidate.template else { return localCandidate }
            let winner = preferredTemplate(local: localCandidate, cloud: cloudCandidate)
            try preserveForRecovery(winner.data == localCandidate.data ? cloudCandidate : localCandidate)
            return winner
        }
    }

    func preferredTemplate(local: StoredTemplate, cloud: StoredTemplate) -> StoredTemplate {
        if local.template.updatedAt == cloud.template.updatedAt {
            let localData = (try? encoded(local.template)) ?? local.data
            let cloudData = (try? encoded(cloud.template)) ?? cloud.data
            return cloudData.lexicographicallyPrecedes(localData) ? local : cloud
        }
        return local.template.updatedAt > cloud.template.updatedAt ? local : cloud
    }

    func storedCloudTemplates(_ snapshot: PromptTemplateCloudSnapshot) throws -> [StoredTemplate] {
        try validateRawCloudSnapshot(snapshot)
        for (id, marker) in snapshot.deletionMarkers where marker.id != id {
            throw PromptTemplateRepositoryError.invalidCloudSnapshot
        }
        guard Set(snapshot.templates.map(\.id)).count == snapshot.templates.count else {
            throw PromptTemplateRepositoryError.invalidCloudSnapshot
        }
        let templates = try snapshot.templates.map { template in
            guard !template.isBuiltIn, let data = snapshot.templateData[template.id] else {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            let decoded: PromptTemplate
            do {
                decoded = try decoder().decode(PromptTemplate.self, from: data)
            } catch {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            let decodedData = try encoded(decoded)
            let snapshotData = try encoded(template)
            guard decoded.id == template.id, decodedData == snapshotData else {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            return StoredTemplate(template: template, data: data)
        }
        guard Set(snapshot.templateData.keys) == Set(templates.map(\.template.id)) else {
            throw PromptTemplateRepositoryError.invalidCloudSnapshot
        }
        return templates
    }

    func mergeDeletionMarkers(
        local: [UUID: CloudDeletionMarker],
        cloud: [UUID: CloudDeletionMarker]
    ) -> [UUID: CloudDeletionMarker] {
        cloud.reduce(into: local) { result, entry in
            if (result[entry.key]?.deletedAt ?? .distantPast) < entry.value.deletedAt {
                result[entry.key] = entry.value
            }
        }
    }

    func shouldKeep(_ template: PromptTemplate, markers: [UUID: CloudDeletionMarker]) -> Bool {
        guard let marker = markers[template.id] else { return true }
        return template.updatedAt > marker.deletedAt
    }

    func applying(
        _ purgeMarker: CloudPurgeMarker?,
        to markers: [UUID: CloudDeletionMarker],
        templates: [StoredTemplate]
    ) -> [UUID: CloudDeletionMarker] {
        guard let purgeMarker else { return markers }
        var output = markers
        for template in templates where template.template.updatedAt <= purgeMarker.deletedAt {
            let existing = output[template.template.id]?.deletedAt ?? .distantPast
            if existing < purgeMarker.deletedAt {
                output[template.template.id] = CloudDeletionMarker(
                    id: template.template.id,
                    deletedAt: purgeMarker.deletedAt
                )
            }
        }
        return output
    }

    func templatesNeedingCloudWrite(
        _ templates: [StoredTemplate],
        cloud: [StoredTemplate]
    ) -> [PromptTemplate] {
        let cloudByID = Dictionary(uniqueKeysWithValues: cloud.map { ($0.template.id, $0.template) })
        return templates.map(\.template).filter { template in
            cloudByID[template.id] != template
        }
    }

    func writeAndVerifyCloudTemplates(
        _ templates: [PromptTemplate],
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws {
        guard !templates.isEmpty else { return }
        try await cloudSyncManager.applyTemplateUploads(templates, basedOn: snapshot)
        let currentSnapshot = try await cloudSyncManager.loadTemplatesFromCloud()
        _ = try storedCloudTemplates(currentSnapshot)
        for template in templates {
            guard currentSnapshot.templates.first(where: { $0.id == template.id }) == template,
                  currentSnapshot.deletionMarkers[template.id] == snapshot.deletionMarkers[template.id] else {
                throw CloudSyncError.cloudContentChanged
            }
        }
    }

    func checkOperationIntent(_ requiredCloudIntent: Bool) throws {
        try Task.checkCancellation()
        guard !requiredCloudIntent || settingsManager.getIsCloudSyncEnabled() else {
            throw CancellationError()
        }
    }

}
