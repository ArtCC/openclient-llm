//
//  CloudSyncManager+ConversationSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func loadConversationSyncSnapshot() throws -> ConversationCloudSyncSnapshot {
        let session = try makeSyncSession()
        guard containerProvider.isMetadataReady(for: session) else {
            throw CloudSyncError.requiredDownloadPending
        }
        return try fileCoordinator.read(at: session.containerURL) { containerURL in
            try validate(session)
            return try makeConversationSnapshot(session: session, containerURL: containerURL)
        }
    }

    func validateConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws {
        try validate(snapshot.session)
        try fileCoordinator.read(at: snapshot.session.containerURL) { containerURL in
            try validate(snapshot.session)
            let current = try makeConversationSnapshot(
                session: snapshot.session,
                containerURL: containerURL
            )
            try validateUnchanged(current, comparedTo: snapshot, output: output)
            try validateOutput(output)
            try validate(snapshot.session)
        }
    }

    func applyConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws {
        try validate(snapshot.session)
        try fileCoordinator.write(at: snapshot.session.containerURL, options: []) { containerURL in
            try validate(snapshot.session)
            let current = try makeConversationSnapshot(
                session: snapshot.session,
                containerURL: containerURL
            )
            try validateUnchanged(current, comparedTo: snapshot, output: output)
            try apply(output, snapshot: snapshot, containerURL: containerURL)
        }
    }
}

// MARK: - Snapshot

private extension CloudSyncManager {
    func makeSyncSession() throws -> CloudSyncSession {
        guard let session = containerProvider.currentSession() else {
            throw CloudSyncError.containerUnavailable
        }
        return session
    }

    func validate(_ session: CloudSyncSession) throws {
        guard let currentSession = containerProvider.currentSession() else {
            throw CloudSyncError.containerUnavailable
        }
        guard currentSession == session else {
            throw CloudSyncError.containerIdentityChanged
        }
        guard containerProvider.isMetadataReady(for: session) else {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func makeConversationSnapshot(
        session: CloudSyncSession,
        containerURL: URL
    ) throws -> ConversationCloudSyncSnapshot {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let manifestURL = documentsURL.appendingPathComponent("SyncManifest.json")
        try requireDownloadedFile(at: manifestURL)
        let manifestData = try dataIfPresent(at: manifestURL)
        _ = try CloudSyncManifest.decode(manifestData)

        let conversationResult = try loadConversations(in: documentsURL)
        let tombstoneResult = try loadTombstones(in: documentsURL)
        let markerResult = try loadDeleteAllMarker(in: documentsURL)
        let attachmentResult = try loadAttachments(in: documentsURL)

        return ConversationCloudSyncSnapshot(
            session: session,
            manifestData: manifestData,
            conversations: conversationResult.values,
            conversationData: conversationResult.data,
            tombstones: tombstoneResult.values,
            tombstoneData: tombstoneResult.data,
            legacyTombstoneData: tombstoneResult.legacyData,
            deleteAllMarker: markerResult.value,
            deleteAllMarkerData: markerResult.data,
            attachmentData: attachmentResult.data,
            attachmentPlaceholders: attachmentResult.placeholders
        )
    }

    func loadConversations(in documentsURL: URL) throws -> RecordFiles<Conversation> {
        let directory = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return RecordFiles() }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        try requireNoPlaceholders(in: files)
        let decoder = SyncJSONCoding.makeDecoder()
        var values: [UUID: Conversation] = [:]
        var dataById: [UUID: Data] = [:]
        for url in files where url.pathExtension == "json" {
            try requireDownloadedFile(at: url)
            let data = try Data(contentsOf: url)
            let conversation = try decoder.decode(Conversation.self, from: data)
            try conversation.validateContextMetadata()
            guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) == conversation.id else {
                throw CloudSyncError.invalidConversationData
            }
            values[conversation.id] = conversation
            dataById[conversation.id] = data
        }
        return RecordFiles(values: values, data: dataById)
    }

    func loadTombstones(in documentsURL: URL) throws -> TombstoneFiles {
        let legacyURL = documentsURL.appendingPathComponent("ConversationTombstones.json")
        try requireDownloadedFile(at: legacyURL)
        let legacyData = try dataIfPresent(at: legacyURL)
        let decoder = SyncJSONCoding.makeDecoder()
        var tombstones = try legacyData.map { try decoder.decode([ConversationTombstone].self, from: $0) } ?? []
        let directory = documentsURL.appendingPathComponent("ConversationTombstones", isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else {
            return TombstoneFiles(values: tombstones, data: [:], legacyData: legacyData)
        }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        try requireNoPlaceholders(in: files)
        var dataById: [UUID: Data] = [:]
        for url in files where url.pathExtension == "json" {
            try requireDownloadedFile(at: url)
            let data = try Data(contentsOf: url)
            let tombstone = try decoder.decode(ConversationTombstone.self, from: data)
            guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) == tombstone.conversationId else {
                throw CloudSyncError.cloudContentChanged
            }
            tombstones.append(tombstone)
            dataById[tombstone.conversationId] = data
        }
        return TombstoneFiles(values: tombstones, data: dataById, legacyData: legacyData)
    }

    func loadDeleteAllMarker(in documentsURL: URL) throws -> MarkerFile {
        let url = documentsURL.appendingPathComponent("ConversationDeleteAll.json")
        try requireDownloadedFile(at: url)
        guard let data = try dataIfPresent(at: url) else { return MarkerFile() }
        let marker = try SyncJSONCoding.makeDecoder().decode(ConversationDeleteAllMarker.self, from: data)
        return MarkerFile(value: marker, data: data)
    }

    func loadAttachments(in documentsURL: URL) throws -> AttachmentFiles {
        let resolver = AttachmentFileResolver(fileManager: fileManager, baseURL: documentsURL)
        let directory = try resolver.attachmentRoot()
        guard fileManager.fileExists(atPath: directory.path) else { return AttachmentFiles() }
        let folders = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var dataByKey: [CloudAttachmentKey: Data] = [:]
        var placeholders = Set<CloudAttachmentKey>()
        for folder in folders {
            let folderValues = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard folderValues.isDirectory == true,
                  folderValues.isSymbolicLink != true,
                  let conversationId = UUID(uuidString: folder.lastPathComponent) else { continue }
            _ = try resolver.conversationDirectory(conversationId)
            let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            for url in files {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory != true else { continue }
                guard values.isSymbolicLink != true else { throw CloudSyncError.invalidAttachmentPath }
                if let fileName = placeholderFileName(for: url) {
                    let key = CloudAttachmentKey(conversationId: conversationId, fileName: fileName)
                    placeholders.insert(key)
                    try? fileManager.startDownloadingUbiquitousItem(at: url)
                    continue
                }
                let key = CloudAttachmentKey(conversationId: conversationId, fileName: url.lastPathComponent)
                let resolvedURL = try resolver.resolve(
                    relativePath: ConversationAttachmentPath.relativePath(for: key)
                )
                if try requiresDownload(at: resolvedURL) {
                    placeholders.insert(key)
                } else {
                    dataByKey[key] = try Data(contentsOf: resolvedURL)
                }
            }
        }
        return AttachmentFiles(data: dataByKey, placeholders: placeholders)
    }

    func requireNoPlaceholders(in files: [URL]) throws {
        let placeholders = files.filter { placeholderFileName(for: $0) != nil }
        for placeholder in placeholders {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
        }
        if !placeholders.isEmpty {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func requireDownloadedFile(at url: URL) throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        if fileManager.fileExists(atPath: placeholder.path) {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
            throw CloudSyncError.requiredDownloadPending
        }
        if fileManager.fileExists(atPath: url.path), try requiresDownload(at: url) {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func dataIfPresent(at url: URL) throws -> Data? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }
}

// MARK: - Apply

private extension CloudSyncManager {
    func validateUnchanged(
        _ current: ConversationCloudSyncSnapshot,
        comparedTo snapshot: ConversationCloudSyncSnapshot,
        output: ConversationCloudSyncOutput
    ) throws {
        guard current.manifestData == snapshot.manifestData,
              current.conversationData == snapshot.conversationData,
              current.tombstoneData == snapshot.tombstoneData,
              current.legacyTombstoneData == snapshot.legacyTombstoneData,
              current.deleteAllMarkerData == snapshot.deleteAllMarkerData else {
            throw CloudSyncError.cloudContentChanged
        }
        guard current.attachmentData == snapshot.attachmentData,
              current.attachmentPlaceholders == snapshot.attachmentPlaceholders else {
            throw CloudSyncError.cloudContentChanged
        }
    }

    func apply(
        _ output: ConversationCloudSyncOutput,
        snapshot: ConversationCloudSyncSnapshot,
        containerURL: URL
    ) throws {
        try Task.checkCancellation()
        try validateOutput(output)
        try validate(snapshot.session)
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try writeManifestIfNeeded(snapshot: snapshot, documentsURL: documentsURL)
        try validate(snapshot.session)
        try writeAttachments(output.attachments, session: snapshot.session, documentsURL: documentsURL)
        try validate(snapshot.session)
        try writeTombstones(output.tombstones, session: snapshot.session, documentsURL: documentsURL)
        try validate(snapshot.session)
        try writeMarker(output.deleteAllMarker, session: snapshot.session, documentsURL: documentsURL)
        try validate(snapshot.session)
        try writeConversations(output, session: snapshot.session, documentsURL: documentsURL)
        try validate(snapshot.session)
        try deleteUnreferencedAttachments(output: output, snapshot: snapshot, documentsURL: documentsURL)
        try validate(snapshot.session)
        try deleteRemovedConversations(output: output, snapshot: snapshot, documentsURL: documentsURL)
        try validate(snapshot.session)
    }

    func validateOutput(_ output: ConversationCloudSyncOutput) throws {
        let conversationIds = Set(output.conversations.map(\.id))
        guard conversationIds.count == output.conversations.count,
              Set(output.conversationData.keys) == conversationIds else {
            throw CloudSyncError.invalidConversationData
        }
        let decoder = SyncJSONCoding.makeDecoder()
        for conversation in output.conversations {
            guard let data = output.conversationData[conversation.id],
                  try decoder.decode(Conversation.self, from: data) == conversation else {
                throw CloudSyncError.invalidConversationData
            }
            try conversation.validateContextMetadata()
        }
        let requiredAttachmentKeys = try referencedAttachmentKeys(in: output.conversations)
        guard requiredAttachmentKeys == Set(output.attachments.keys) else {
            throw CloudSyncError.missingAttachment
        }
    }

    func writeManifestIfNeeded(
        snapshot: ConversationCloudSyncSnapshot,
        documentsURL: URL
    ) throws {
        let url = documentsURL.appendingPathComponent("SyncManifest.json")
        guard snapshot.manifestData == nil else { return }
        let data = try JSONEncoder().encode(CloudSyncManifest.current)
        try writeAndVerify(data, to: url)
        _ = try CloudSyncManifest.decode(Data(contentsOf: url))
    }

    func writeAttachments(
        _ attachments: [CloudAttachmentKey: Data],
        session: CloudSyncSession,
        documentsURL: URL
    ) throws {
        let resolver = AttachmentFileResolver(fileManager: fileManager, baseURL: documentsURL)
        _ = try resolver.attachmentRoot()
        for (key, data) in attachments {
            try Task.checkCancellation()
            try validate(session)
            let folder = try resolver.conversationDirectory(key.conversationId)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = try resolver.resolve(relativePath: ConversationAttachmentPath.relativePath(for: key))
            try writeAndVerify(data, to: fileURL)
            try validate(session)
        }
    }

    func writeTombstones(
        _ tombstones: [ConversationTombstone],
        session: CloudSyncSession,
        documentsURL: URL
    ) throws {
        let directory = documentsURL.appendingPathComponent("ConversationTombstones", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = SyncJSONCoding.makeEncoder()
        let decoder = SyncJSONCoding.makeDecoder()
        for tombstone in tombstones {
            try Task.checkCancellation()
            try validate(session)
            let url = directory.appendingPathComponent("\(tombstone.conversationId.uuidString).json")
            let data = try encoder.encode(tombstone)
            try writeAndVerify(data, to: url)
            _ = try decoder.decode(ConversationTombstone.self, from: Data(contentsOf: url))
            try validate(session)
        }
    }

    func writeMarker(
        _ marker: ConversationDeleteAllMarker?,
        session: CloudSyncSession,
        documentsURL: URL
    ) throws {
        guard let marker else { return }
        try validate(session)
        let url = documentsURL.appendingPathComponent("ConversationDeleteAll.json")
        let data = try SyncJSONCoding.makeEncoder().encode(marker)
        try writeAndVerify(data, to: url)
        _ = try SyncJSONCoding.makeDecoder().decode(
            ConversationDeleteAllMarker.self,
            from: Data(contentsOf: url)
        )
        try validate(session)
    }

    func writeConversations(
        _ output: ConversationCloudSyncOutput,
        session: CloudSyncSession,
        documentsURL: URL
    ) throws {
        let directory = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let decoder = SyncJSONCoding.makeDecoder()
        for conversation in output.conversations {
            try Task.checkCancellation()
            try validate(session)
            let url = directory.appendingPathComponent("\(conversation.id.uuidString).json")
            guard let data = output.conversationData[conversation.id] else {
                throw CloudSyncError.invalidConversationData
            }
            try writeAndVerify(data, to: url)
            guard try decoder.decode(Conversation.self, from: Data(contentsOf: url)) == conversation else {
                throw CloudSyncError.invalidConversationData
            }
            try validate(session)
        }
    }

    func deleteRemovedConversations(
        output: ConversationCloudSyncOutput,
        snapshot: ConversationCloudSyncSnapshot,
        documentsURL: URL
    ) throws {
        let survivingIds = Set(output.conversations.map(\.id))
        let removedIds = Set(snapshot.conversations.keys).subtracting(survivingIds)
        let conversationsURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        let resolver = AttachmentFileResolver(fileManager: fileManager, baseURL: documentsURL)
        for id in removedIds {
            try Task.checkCancellation()
            try validate(snapshot.session)
            try removeDirectlyIfPresent(at: conversationsURL.appendingPathComponent("\(id.uuidString).json"))
            try removeDirectlyIfPresent(at: resolver.conversationDirectory(id))
            try validate(snapshot.session)
        }
    }

    func deleteUnreferencedAttachments(
        output: ConversationCloudSyncOutput,
        snapshot: ConversationCloudSyncSnapshot,
        documentsURL: URL
    ) throws {
        let referencedKeys = Set(output.attachments.keys)
        let existingKeys = Set(snapshot.attachmentData.keys).union(snapshot.attachmentPlaceholders)
        let resolver = AttachmentFileResolver(fileManager: fileManager, baseURL: documentsURL)
        for key in existingKeys.subtracting(referencedKeys) {
            try Task.checkCancellation()
            try validate(snapshot.session)
            let folder = try resolver.conversationDirectory(key.conversationId)
            let fileURL = try resolver.resolve(relativePath: ConversationAttachmentPath.relativePath(for: key))
            let placeholderPath = "Attachments/\(key.conversationId.uuidString)/.\(key.fileName).icloud"
            let placeholderURL = try resolver.resolve(relativePath: placeholderPath)
            try removeDirectlyIfPresent(at: fileURL)
            try removeDirectlyIfPresent(at: placeholderURL)
            if let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
               contents.isEmpty {
                try removeDirectlyIfPresent(at: folder)
            }
            try validate(snapshot.session)
        }
    }

    func writeAndVerify(_ data: Data, to url: URL) throws {
        if try dataIfPresent(at: url) != data {
            try data.write(to: url, options: .atomic)
        }
        guard try Data(contentsOf: url) == data else {
            throw CloudSyncError.cloudContentChanged
        }
    }

    func removeDirectlyIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
        guard !fileManager.fileExists(atPath: url.path) else {
            throw CloudSyncError.cloudContentChanged
        }
    }
}

// MARK: - Helpers

private extension CloudSyncManager {
    nonisolated struct RecordFiles<Value: Sendable>: Sendable {
        var values: [UUID: Value] = [:]
        var data: [UUID: Data] = [:]
    }

    nonisolated struct TombstoneFiles: Sendable {
        var values: [ConversationTombstone] = []
        var data: [UUID: Data] = [:]
        var legacyData: Data?
    }

    nonisolated struct MarkerFile: Sendable {
        var value: ConversationDeleteAllMarker?
        var data: Data?
    }

    nonisolated struct AttachmentFiles: Sendable {
        var data: [CloudAttachmentKey: Data] = [:]
        var placeholders: Set<CloudAttachmentKey> = []
    }

    func referencedAttachmentKeys(in conversations: [Conversation]) throws -> Set<CloudAttachmentKey> {
        var keys = Set<CloudAttachmentKey>()
        for conversation in conversations {
            for attachment in conversation.messages.flatMap(\.attachments) {
                if let key = try ConversationAttachmentPath.key(for: attachment, conversationId: conversation.id) {
                    keys.insert(key)
                }
            }
        }
        return keys
    }

    func placeholderFileName(for url: URL) -> String? {
        let name = url.lastPathComponent
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
