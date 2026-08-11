//
//  CloudSyncManager+Functions.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    static let profileMarkerId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    func cloudDocumentsDirectory() -> URL? {
        containerProvider.containerURL()?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func requiresDownload(at url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        guard let status = values.ubiquitousItemDownloadingStatus, status != .current else { return false }
        try? fileManager.startDownloadingUbiquitousItem(at: url)
        return true
    }

    func readCategory<Value: Sendable>(
        _ operation: @escaping @Sendable (CloudSyncManager, URL) throws -> Value
    ) async throws -> Value {
        let session = try makeCategorySession()
        return try await fileCoordinator.read(at: session.containerURL) { containerURL in
            try validateCategorySession(session)
            let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            try validateCategoryManifest(in: documentsURL)
            let value = try operation(self, documentsURL)
            try validateCategorySession(session)
            return value
        }
    }

    func mutateCategory<Value: Sendable>(
        _ operation: @escaping @Sendable (CloudSyncManager, URL) throws -> Value
    ) async throws -> Value {
        let session = try makeCategorySession()
        return try await fileCoordinator.write(at: session.containerURL, options: []) { containerURL in
            try validateCategorySession(session)
            let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            try validateCategoryManifest(in: documentsURL)
            try ensureDirectoryExists(at: documentsURL)
            try writeCategoryManifestIfNeeded(in: documentsURL)
            let value = try operation(self, documentsURL)
            try validateCategorySession(session)
            return value
        }
    }

    func writeEncoded<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        if fileManager.fileExists(atPath: url.path), try Data(contentsOf: url) == data { return }
        try ensureDirectoryExists(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else { throw CloudSyncError.cloudContentChanged }
    }

    func decode<Value: Decodable>(_ type: Value.Type, at url: URL) throws -> Value {
        try requireCategoryFileReady(at: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    func decodeIfPresent<Value: Decodable>(_ type: Value.Type, at url: URL) throws -> Value? {
        try requireCategoryFileReady(at: url)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decode(type, at: url)
    }

    func categoryContents(of directory: URL) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where categoryPlaceholderName(for: url) != nil {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }
        guard !urls.contains(where: { categoryPlaceholderName(for: $0) != nil }) else {
            throw CloudSyncError.requiredDownloadPending
        }
        for url in urls where try requiresDownload(at: url) {
            throw CloudSyncError.requiredDownloadPending
        }
        return urls
    }

    func loadTemplateDeletionIds(in documentsURL: URL) throws -> Set<UUID> {
        let directory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        return Set(try categoryContents(of: directory).compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            return try decode(CloudDeletionMarker.self, at: url).id
        })
    }

    func loadMemoryDeletionMarkers(in documentsURL: URL) throws -> [CloudDeletionMarker] {
        let markers = try decodeIfPresent(
            [CloudDeletionMarker].self,
            at: documentsURL.appendingPathComponent("MemoryTombstones.json")
        ) ?? []
        var newestById: [UUID: CloudDeletionMarker] = [:]
        for marker in markers {
            if let current = newestById[marker.id], current.deletedAt >= marker.deletedAt { continue }
            newestById[marker.id] = marker
        }
        return newestById.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func loadProfileState(in documentsURL: URL) throws -> CloudUserProfileState {
        let profile = try decodeIfPresent(
            UserProfile.self,
            at: documentsURL.appendingPathComponent("UserProfile.json")
        )
        let marker = try decodeIfPresent(
            CloudDeletionMarker.self,
            at: documentsURL.appendingPathComponent("UserProfileDeletion.json")
        )
        guard let marker else { return profile.map(CloudUserProfileState.profile) ?? .missing }
        guard marker.id == Self.profileMarkerId else { throw CloudSyncError.cloudContentChanged }
        guard let profile, profile.modifiedAt > marker.deletedAt else { return .deleted(marker) }
        return .profile(profile)
    }

    func requireCategoryFileReady(at url: URL) throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        if fileManager.fileExists(atPath: placeholder.path) {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
            throw CloudSyncError.requiredDownloadPending
        }
        if fileManager.fileExists(atPath: url.path), try requiresDownload(at: url) {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func removeCategoryItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
        guard !fileManager.fileExists(atPath: url.path) else { throw CloudSyncError.cloudContentChanged }
    }

    private func makeCategorySession() throws -> CloudSyncSession {
        guard let session = containerProvider.currentSession() else { throw CloudSyncError.containerUnavailable }
        guard containerProvider.isMetadataReady(for: session) else {
            throw CloudSyncError.requiredDownloadPending
        }
        return session
    }

    private func validateCategorySession(_ session: CloudSyncSession) throws {
        guard let current = containerProvider.currentSession() else { throw CloudSyncError.containerUnavailable }
        guard current == session else { throw CloudSyncError.containerIdentityChanged }
        guard containerProvider.isMetadataReady(for: session) else {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    private func validateCategoryManifest(in documentsURL: URL) throws {
        let url = documentsURL.appendingPathComponent("SyncManifest.json")
        try requireCategoryFileReady(at: url)
        let data = fileManager.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        _ = try CloudSyncManifest.decode(data)
    }

    private func writeCategoryManifestIfNeeded(in documentsURL: URL) throws {
        let url = documentsURL.appendingPathComponent("SyncManifest.json")
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try writeEncoded(CloudSyncManifest.current, to: url)
    }

    private func categoryPlaceholderName(for url: URL) -> String? {
        let name = url.lastPathComponent
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

}
