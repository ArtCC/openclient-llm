//
//  CloudSyncManager+SnapshotCategories.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func loadMemorySnapshot() async throws -> MemoryCloudSyncSnapshot {
        let session = try makeCategorySession()
        return try await fileCoordinator.read(at: session.containerURL) { containerURL in
            try validateCategorySession(session)
            let snapshot = try makeMemorySnapshot(session: session, containerURL: containerURL)
            try validateCategorySession(session)
            return snapshot
        }
    }

    func applyMemoryOutput(
        items: [MemoryItem],
        deletionMarkers: [CloudDeletionMarker],
        basedOn snapshot: MemoryCloudSyncSnapshot
    ) async throws {
        try validateCategorySession(snapshot.session)
        try await fileCoordinator.write(at: snapshot.session.containerURL, options: []) { containerURL in
            try validateCategorySession(snapshot.session)
            let current = try makeMemorySnapshot(session: snapshot.session, containerURL: containerURL)
            guard current.memoryData == snapshot.memoryData,
                  current.deletionMarkerData == snapshot.deletionMarkerData,
                  current.purgeMarker == snapshot.purgeMarker else {
                throw CloudSyncError.cloudContentChanged
            }
            try writeMemoryOutput(
                items: items,
                deletionMarkers: deletionMarkers,
                session: snapshot.session,
                containerURL: containerURL
            )
            try validateCategorySession(snapshot.session)
        }
    }

    func loadTemplateSnapshot() async throws -> PromptTemplateCloudSnapshot {
        let session = try makeCategorySession()
        return try await fileCoordinator.read(at: session.containerURL) { containerURL in
            try validateCategorySession(session)
            let snapshot = try makeTemplateSnapshot(session: session, containerURL: containerURL)
            try validateCategorySession(session)
            return snapshot
        }
    }

    func applyTemplateSnapshotUploads(
        _ templates: [PromptTemplate],
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws {
        try validateCategorySession(snapshot.session)
        try await fileCoordinator.write(at: snapshot.session.containerURL, options: []) { containerURL in
            try validateCategorySession(snapshot.session)
            let current = try makeTemplateSnapshot(session: snapshot.session, containerURL: containerURL)
            guard current.templateDirectoryData == snapshot.templateDirectoryData,
                  current.tombstoneDirectoryData == snapshot.tombstoneDirectoryData,
                  current.templateDirectoryExists == snapshot.templateDirectoryExists,
                  current.tombstoneDirectoryExists == snapshot.tombstoneDirectoryExists,
                  current.purgeMarker == snapshot.purgeMarker else {
                throw CloudSyncError.cloudContentChanged
            }
            try writeTemplateUploads(templates, session: snapshot.session, containerURL: containerURL)
            try validateCategorySession(snapshot.session)
        }
    }

    func applyTemplateSnapshotDeletion(
        _ marker: CloudDeletionMarker,
        basedOn snapshot: PromptTemplateCloudSnapshot
    ) async throws {
        try validateCategorySession(snapshot.session)
        try await fileCoordinator.write(at: snapshot.session.containerURL, options: []) { containerURL in
            try validateCategorySession(snapshot.session)
            let current = try makeTemplateSnapshot(session: snapshot.session, containerURL: containerURL)
            try requireMatchingTemplateDirectories(current, snapshot)
            try writeTemplateDeletion(marker, session: snapshot.session, containerURL: containerURL)
            try validateCategorySession(snapshot.session)
        }
    }
}

// MARK: - Memory

private extension CloudSyncManager {
    func makeMemorySnapshot(
        session: CloudSyncSession,
        containerURL: URL
    ) throws -> MemoryCloudSyncSnapshot {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try validateCategoryManifest(in: documentsURL)
        let memoryURL = documentsURL.appendingPathComponent("Memory.json")
        let markerURL = documentsURL.appendingPathComponent("MemoryTombstones.json")
        try requireCategoryFileReady(at: memoryURL)
        try requireCategoryFileReady(at: markerURL)
        let memoryData = try categoryDataIfPresent(at: memoryURL)
        let markerData = try categoryDataIfPresent(at: markerURL)
        let purgeMarker = try readPurgeMarker(in: documentsURL)
        let items = try memoryData.map { try SyncJSONCoding.makeDecoder().decode([MemoryItem].self, from: $0) }
        let rawMarkers = try markerData.map {
            try SyncJSONCoding.makeDecoder().decode([CloudDeletionMarker].self, from: $0)
        } ?? []
        let markers = newestMarkers(rawMarkers)
        let markerByID = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
        let eligibleItems = items?.filter { item in
            guard item.updatedAt > (purgeMarker?.deletedAt ?? .distantPast) else { return false }
            guard let marker = markerByID[item.id] else { return true }
            return item.updatedAt > marker.deletedAt
        }
        return MemoryCloudSyncSnapshot(
            session: session,
            items: eligibleItems,
            deletionMarkers: markers,
            memoryData: memoryData,
            deletionMarkerData: markerData,
            purgeMarker: purgeMarker
        )
    }

    func writeMemoryOutput(
        items: [MemoryItem],
        deletionMarkers: [CloudDeletionMarker],
        session: CloudSyncSession,
        containerURL: URL
    ) throws {
        let markers = newestMarkers(deletionMarkers)
        guard markers.count == Set(deletionMarkers.map(\.id)).count else {
            throw CloudSyncError.cloudContentChanged
        }
        let markerByID = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
        let purgeMarker = try readPurgeMarker(
            in: containerURL.appendingPathComponent("Documents", isDirectory: true)
        )
        let eligibleItems = items.filter { item in
            guard item.updatedAt > (purgeMarker?.deletedAt ?? .distantPast) else { return false }
            guard let marker = markerByID[item.id] else { return true }
            return item.updatedAt > marker.deletedAt
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        guard Set(eligibleItems.map(\.id)).count == eligibleItems.count else {
            throw CloudSyncError.cloudContentChanged
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try ensureDirectoryExists(at: documentsURL)
        try writeCategoryManifestIfNeeded(in: documentsURL)
        try validateCategorySession(session)
        try writeMemoryValue(markers, to: documentsURL.appendingPathComponent("MemoryTombstones.json"))
        try validateCategorySession(session)
        try writeMemoryValue(eligibleItems, to: documentsURL.appendingPathComponent("Memory.json"))
        try validateCategorySession(session)
    }

    func newestMarkers(_ markers: [CloudDeletionMarker]) -> [CloudDeletionMarker] {
        var newestByID: [UUID: CloudDeletionMarker] = [:]
        for marker in markers where (newestByID[marker.id]?.deletedAt ?? .distantPast) < marker.deletedAt {
            newestByID[marker.id] = marker
        }
        return newestByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

// MARK: - Prompt Templates

private extension CloudSyncManager {
    struct TemplateDirectorySnapshot {
        let templates: [PromptTemplate]
        let templateData: [UUID: Data]
        let markers: [UUID: CloudDeletionMarker]
        let templateDirectoryData: [String: Data]
        let tombstoneDirectoryData: [String: Data]
        let templateDirectoryExists: Bool
        let tombstoneDirectoryExists: Bool
    }

    func makeTemplateSnapshot(
        session: CloudSyncSession,
        containerURL: URL
    ) throws -> PromptTemplateCloudSnapshot {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try validateCategoryManifest(in: documentsURL)
        let purgeMarker = try readPurgeMarker(in: documentsURL)
        let directorySnapshot = try loadTemplateDirectories(in: documentsURL)
        let eligibleTemplates = directorySnapshot.templates.filter { template in
            guard template.updatedAt > (purgeMarker?.deletedAt ?? .distantPast) else { return false }
            guard let marker = directorySnapshot.markers[template.id] else { return true }
            return template.updatedAt > marker.deletedAt
        }
        let eligibleIDs = Set(eligibleTemplates.map(\.id))
        return PromptTemplateCloudSnapshot(
            session: session,
            templates: eligibleTemplates,
            templateData: directorySnapshot.templateData.filter { eligibleIDs.contains($0.key) },
            rawTemplates: Dictionary(uniqueKeysWithValues: directorySnapshot.templates.map { ($0.id, $0) }),
            staleTemplateIds: Set(directorySnapshot.templates.compactMap { template in
                guard let marker = directorySnapshot.markers[template.id],
                      template.updatedAt <= marker.deletedAt else { return nil }
                return template.id
            }),
            deletionMarkers: directorySnapshot.markers,
            templateDirectoryData: directorySnapshot.templateDirectoryData,
            tombstoneDirectoryData: directorySnapshot.tombstoneDirectoryData,
            templateDirectoryExists: directorySnapshot.templateDirectoryExists,
            tombstoneDirectoryExists: directorySnapshot.tombstoneDirectoryExists,
            purgeMarker: purgeMarker
        )
    }

    func loadTemplateDirectories(in documentsURL: URL) throws -> TemplateDirectorySnapshot {
        let templateURL = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        let tombstoneURL = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        let templateFiles = try loadDirectoryData(at: templateURL)
        let tombstoneFiles = try loadDirectoryData(at: tombstoneURL)
        let decoder = SyncJSONCoding.makeDecoder()
        var templates: [PromptTemplate] = []
        var templateData: [UUID: Data] = [:]
        for (name, data) in templateFiles {
            let id = try validatedJSONFileID(name)
            let template = try decoder.decode(PromptTemplate.self, from: data)
            guard template.id == id, !template.isBuiltIn, templateData[id] == nil else {
                throw CloudSyncError.cloudContentChanged
            }
            templates.append(template)
            templateData[id] = data
        }
        var markers: [UUID: CloudDeletionMarker] = [:]
        for (name, data) in tombstoneFiles {
            let id = try validatedJSONFileID(name)
            let marker = try decoder.decode(CloudDeletionMarker.self, from: data)
            guard marker.id == id, markers[id] == nil else { throw CloudSyncError.cloudContentChanged }
            markers[id] = marker
        }
        return TemplateDirectorySnapshot(
            templates: templates,
            templateData: templateData,
            markers: markers,
            templateDirectoryData: templateFiles,
            tombstoneDirectoryData: tombstoneFiles,
            templateDirectoryExists: fileManager.fileExists(atPath: templateURL.path),
            tombstoneDirectoryExists: fileManager.fileExists(atPath: tombstoneURL.path)
        )
    }

    func loadDirectoryData(at directory: URL) throws -> [String: Data] {
        try requireCategoryFileReady(at: directory)
        guard fileManager.fileExists(atPath: directory.path) else { return [:] }
        let urls = try categoryContents(of: directory)
        return try Dictionary(uniqueKeysWithValues: urls.map { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory != true, values.isSymbolicLink != true else {
                throw CloudSyncError.cloudContentChanged
            }
            return (url.lastPathComponent, try Data(contentsOf: url))
        })
    }

    func validatedJSONFileID(_ name: String) throws -> UUID {
        let url = URL(fileURLWithPath: name)
        guard url.pathExtension == "json",
              url.lastPathComponent == name,
              let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
              url.deletingPathExtension().lastPathComponent == id.uuidString else {
            throw CloudSyncError.cloudContentChanged
        }
        return id
    }

    func writeTemplateUploads(
        _ templates: [PromptTemplate],
        session: CloudSyncSession,
        containerURL: URL
    ) throws {
        guard Set(templates.map(\.id)).count == templates.count,
              templates.allSatisfy({ !$0.isBuiltIn }) else {
            throw CloudSyncError.cloudContentChanged
        }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let templateDirectory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try ensureDirectoryExists(at: documentsURL)
        try writeCategoryManifestIfNeeded(in: documentsURL)
        try ensureDirectoryExists(at: templateDirectory)
        let purgeMarker = try readPurgeMarker(in: documentsURL)
        for template in templates {
            try Task.checkCancellation()
            try validateCategorySession(session)
            let markerURL = documentsURL.appendingPathComponent(
                "PromptTemplateTombstones/\(template.id.uuidString).json"
            )
            if let marker = try decodeIfPresent(CloudDeletionMarker.self, at: markerURL),
               template.updatedAt <= marker.deletedAt {
                throw CloudSyncError.cloudContentChanged
            }
            guard template.updatedAt > (purgeMarker?.deletedAt ?? .distantPast) else {
                throw CloudSyncError.cloudContentChanged
            }
            let url = templateDirectory.appendingPathComponent("\(template.id.uuidString).json")
            try writeEncoded(template, to: url)
            let written = try decode(PromptTemplate.self, at: url)
            guard written == template, written.id == template.id else {
                throw CloudSyncError.cloudContentChanged
            }
            try validateCategorySession(session)
        }
    }

    func writeTemplateDeletion(
        _ proposedMarker: CloudDeletionMarker,
        session: CloudSyncSession,
        containerURL: URL
    ) throws {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let markerDirectory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        try ensureDirectoryExists(at: documentsURL)
        try writeCategoryManifestIfNeeded(in: documentsURL)
        try ensureDirectoryExists(at: markerDirectory)
        try Task.checkCancellation()
        try validateCategorySession(session)
        let markerURL = markerDirectory.appendingPathComponent("\(proposedMarker.id.uuidString).json")
        let existing = try decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
        let marker = existing.map { $0.deletedAt >= proposedMarker.deletedAt ? $0 : proposedMarker } ?? proposedMarker
        try writeEncoded(marker, to: markerURL)
        try Task.checkCancellation()
        try validateCategorySession(session)
        let payloadURL = documentsURL.appendingPathComponent("PromptTemplates/\(marker.id.uuidString).json")
        if let template = try decodeIfPresent(PromptTemplate.self, at: payloadURL),
           template.updatedAt <= marker.deletedAt {
            try removeCategoryItemIfPresent(at: payloadURL)
        }
        try validateCategorySession(session)
    }

    func requireMatchingTemplateDirectories(
        _ current: PromptTemplateCloudSnapshot,
        _ expected: PromptTemplateCloudSnapshot
    ) throws {
        guard current.session == expected.session,
              current.templateDirectoryData == expected.templateDirectoryData,
              current.tombstoneDirectoryData == expected.tombstoneDirectoryData,
              current.templateDirectoryExists == expected.templateDirectoryExists,
              current.tombstoneDirectoryExists == expected.tombstoneDirectoryExists,
              current.purgeMarker == expected.purgeMarker else {
            throw CloudSyncError.cloudContentChanged
        }
    }

    func categoryDataIfPresent(at url: URL) throws -> Data? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }
}
