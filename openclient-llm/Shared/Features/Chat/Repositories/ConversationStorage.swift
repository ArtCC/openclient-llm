//
//  ConversationStorage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor ConversationStorage {
    // MARK: - Properties

    let fileManager: FileManager
    let documentsURL: URL
    let directoryURL: URL
    let tombstonesURL: URL
    let deleteAllMarkerURL: URL
    let localResetMarkerURL: URL
    let pendingMutationsURL: URL
    let recoveryDirectoryURL: URL
    let cloudSyncManager: CloudSyncManagerProtocol
    let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        attachmentRepository: AttachmentRepositoryProtocol? = nil,
        baseDirectory: URL? = nil
    ) {
        let fileManager = FileManager.default
        self.fileManager = fileManager
        let documentsURL = baseDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsURL = documentsURL
        self.directoryURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        self.tombstonesURL = documentsURL.appendingPathComponent("ConversationTombstones.json")
        self.deleteAllMarkerURL = documentsURL.appendingPathComponent("ConversationDeleteAll.json")
        self.localResetMarkerURL = documentsURL.appendingPathComponent("ConversationLocalReset.json")
        self.pendingMutationsURL = documentsURL.appendingPathComponent(
            "ConversationPendingMutations",
            isDirectory: true
        )
        self.recoveryDirectoryURL = documentsURL.appendingPathComponent("ConversationRecovery", isDirectory: true)
        self.cloudSyncManager = cloudSyncManager
        self.attachmentRepository = attachmentRepository
            ?? AttachmentRepository(fileManager: fileManager, baseURL: documentsURL)
    }

    // MARK: - Public

    func loadLocal() throws -> [Conversation] {
        try ensureDirectoryExists()
        let tombstones = try loadTombstones()
        let marker = try loadDeleteAllMarker()
        return try loadLocalConversations()
            .filter { shouldKeep($0, tombstones: tombstones, marker: marker) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: Conversation) throws {
        try ensureDirectoryExists()
        let canonical = try canonicalConversation(conversation)
        let existing = try loadLocalConversation(id: canonical.conversation.id)
        if let existing, existing.updatedAt > canonical.conversation.updatedAt {
            return
        }
        var conversation = canonical.conversation
        conversation.updatedAt = try modificationDate(
            requested: conversation.updatedAt,
            after: deletionBarrier(for: conversation.id)
        )
        if let existing {
            guard existing != conversation || !canonical.attachmentData.isEmpty else { return }
            try persistLocalMutation(
                conversation,
                replacing: existing,
                pendingBase: nil,
                attachmentData: canonical.attachmentData
            )
        } else {
            try persistNewLocalConversation(conversation, attachmentData: canonical.attachmentData)
        }
    }

    func delete(_ conversationId: UUID, synchronize: Bool) throws {
        guard synchronize else {
            try deleteLocally(conversationId)
            return
        }
        guard cloudSyncManager.isCloudAvailable() else {
            throw CloudSyncError.containerUnavailable
        }
        for attempt in 0..<2 {
            do {
                let snapshot = try cloudSyncManager.loadConversationSyncSnapshot()
                try delete(conversationId, using: snapshot)
                return
            } catch CloudSyncError.cloudContentChanged where attempt == 0 {
                continue
            }
        }
        throw CloudSyncError.cloudContentChanged
    }

    func deleteAll(synchronize: Bool) throws {
        guard synchronize else {
            try deleteAllLocally()
            return
        }
        guard cloudSyncManager.isCloudAvailable() else {
            throw CloudSyncError.containerUnavailable
        }
        for attempt in 0..<2 {
            do {
                let snapshot = try cloudSyncManager.loadConversationSyncSnapshot()
                try deleteAll(using: snapshot)
                return
            } catch CloudSyncError.cloudContentChanged where attempt == 0 {
                continue
            }
        }
        throw CloudSyncError.cloudContentChanged
    }

    private func deleteLocally(_ conversationId: UUID) throws {
        try Task.checkCancellation()
        try ensureDirectoryExists()
        let attachmentKeys: Set<CloudAttachmentKey>
        if let conversation = try loadLocalConversation(id: conversationId) {
            attachmentKeys = try storedAttachmentKeys(in: conversation)
        } else {
            attachmentKeys = []
        }
        let transaction = try ConversationLocalTransaction(
            fileManager: fileManager,
            documentsURL: documentsURL,
            backsUpAllAttachments: true
        )
        do {
            try applyLocalDelete(conversationId)
            try transaction.commit(verifying: .init(
                absentConversationIds: [conversationId],
                absentPendingMutationIds: [conversationId],
                absentAttachmentKeys: attachmentKeys,
                emptyAttachments: false
            ))
        } catch {
            try transaction.rollback()
            throw error
        }
        try removeRecoveryData(conversationId: conversationId)
    }

    private func deleteAllLocally() throws {
        try Task.checkCancellation()
        try ensureDirectoryExists()
        let transaction = try ConversationLocalTransaction(
            fileManager: fileManager,
            documentsURL: documentsURL,
            backsUpAllAttachments: true
        )
        do {
            try applyLocalDeleteAll(createCloudMarker: false)
            try transaction.commit(verifying: .init(
                emptyConversations: true,
                emptyPendingMutations: true,
                emptyAttachments: true
            ))
        } catch {
            try transaction.rollback()
            throw error
        }
        if fileManager.fileExists(atPath: recoveryDirectoryURL.path) {
            try fileManager.removeItem(at: recoveryDirectoryURL)
        }
        try ensureDirectoryExists()
    }

    @discardableResult
    func synchronize() -> ConversationSyncResult {
        guard !Task.isCancelled else { return .unavailable }
        guard cloudSyncManager.isCloudAvailable() else { return .unavailable }
        for attempt in 0..<2 {
            do {
                try ensureDirectoryExists()
                let snapshot = try cloudSyncManager.loadConversationSyncSnapshot()
                try synchronize(with: snapshot)
                return .synchronized
            } catch CloudSyncError.cloudContentChanged where attempt == 0 {
                continue
            } catch CloudSyncError.requiredDownloadPending {
                return .pendingDownload
            } catch CloudSyncError.containerUnavailable {
                return .unavailable
            } catch CloudSyncError.containerIdentityChanged {
                return .unavailable
            } catch is CancellationError {
                return .unavailable
            } catch {
                LogManager.error("Conversation synchronization failed category=storage")
                return .failed
            }
        }
        return .failed
    }
}

// MARK: - Synchronization

extension ConversationStorage {
    struct ConversationFiles {
        var values: [UUID: Conversation] = [:]
        var data: [UUID: Data] = [:]
    }

    struct MergedConversation {
        let conversation: Conversation
        let data: Data
        let source: Source
        let localInlineAttachmentData: [CloudAttachmentKey: Data]
        let cloudInlineAttachmentData: [CloudAttachmentKey: Data]
    }

    enum Source: Equatable {
        case local
        case cloud
        case equivalent
    }

    struct SynchronizationPlan {
        let output: ConversationCloudSyncOutput
        let mutatedConversation: Conversation?
        let resolvedPendingMutationIds: Set<UUID>
        let localAttachmentKeys: Set<CloudAttachmentKey>
        let localConflictAttachmentKeys: Set<CloudAttachmentKey>
    }

    @discardableResult
    func synchronize(
        with snapshot: ConversationCloudSyncSnapshot,
        conversationId: UUID? = nil,
        mutationAttachmentData: [CloudAttachmentKey: Data] = [:],
        mutation: ((inout Conversation, [Conversation]) throws -> Void)? = nil
    ) throws -> Conversation? {
        let plan = try makeSynchronizationPlan(
            snapshot: snapshot,
            conversationId: conversationId,
            mutationAttachmentData: mutationAttachmentData,
            mutation: mutation
        )
        try Task.checkCancellation()
        try commitSynchronization(
            output: plan.output,
            snapshot: snapshot,
            resolvedPendingMutationIds: plan.resolvedPendingMutationIds,
            localAttachmentKeys: plan.localAttachmentKeys,
            localConflictAttachmentKeys: plan.localConflictAttachmentKeys
        )
        return plan.mutatedConversation
    }

    func makeSynchronizationPlan(
        snapshot: ConversationCloudSyncSnapshot,
        conversationId: UUID?,
        mutationAttachmentData: [CloudAttachmentKey: Data] = [:],
        additionalTombstones: [ConversationTombstone] = [],
        deleteAllMarkerOverride: ConversationDeleteAllMarker? = nil,
        mutation: ((inout Conversation, [Conversation]) throws -> Void)?
    ) throws -> SynchronizationPlan {
        let local = try loadLocalConversationFiles()
        let localAttachmentData = try loadLocalAttachmentFiles()
        let localTombstones = try loadTombstones()
        let pendingMutationBases = try loadPendingMutationBases()
        let marker = newestMarker(
            newestMarker(try loadDeleteAllMarker(), snapshot.deleteAllMarker),
            deleteAllMarkerOverride
        )
        let tombstones = mergeTombstones(localTombstones + snapshot.tombstones + additionalTombstones)
        var merged = try mergeConversations(context: MergeContext(
            local: local,
            snapshot: snapshot,
            tombstones: tombstones,
            deleteAllMarker: marker,
            pendingMutationBases: pendingMutationBases,
            localAttachmentData: localAttachmentData
        ))
        let mutatedConversation = try mutateMergedConversation(
            conversationId: conversationId,
            merged: &merged,
            attachmentData: mutationAttachmentData,
            mutation: mutation
        )
        let output = try makeSyncOutput(
            merged: merged,
            tombstones: tombstones,
            marker: marker,
            snapshot: snapshot
        )
        let localAttachmentKeys = try local.values.values.reduce(
            into: Set<CloudAttachmentKey>()
        ) { keys, conversation in
            keys.formUnion(try storedAttachmentKeys(in: conversation))
        }
        let localConflictAttachmentKeys = try localConflictAttachmentKeys(
            local: local,
            merged: merged,
            tombstones: tombstones,
            marker: marker
        )
        return SynchronizationPlan(
            output: output,
            mutatedConversation: mutatedConversation,
            resolvedPendingMutationIds: Set(pendingMutationBases.keys),
            localAttachmentKeys: localAttachmentKeys,
            localConflictAttachmentKeys: localConflictAttachmentKeys
        )
    }

    func makeSyncOutput(
        merged: [MergedConversation],
        tombstones: [ConversationTombstone],
        marker: ConversationDeleteAllMarker?,
        snapshot: ConversationCloudSyncSnapshot
    ) throws -> ConversationCloudSyncOutput {
        let tombstones = try makeDecoder().decode(
            [ConversationTombstone].self,
            from: makeEncoder().encode(tombstones)
        )
        let marker = try marker.map {
            try makeDecoder().decode(
                ConversationDeleteAllMarker.self,
                from: makeEncoder().encode($0)
            )
        }
        try requireConflictRecoveryDownloads(
            snapshot: snapshot,
            merged: merged,
            tombstones: tombstones,
            marker: marker
        )
        let output = ConversationCloudSyncOutput(
            conversations: merged.map(\.conversation),
            conversationData: Dictionary(uniqueKeysWithValues: merged.map { ($0.conversation.id, $0.data) }),
            tombstones: tombstones,
            deleteAllMarker: marker,
            attachments: try resolvedAttachments(for: merged, snapshot: snapshot)
        )
        try preserveRemovedCloudAttachments(
            output: output,
            snapshot: snapshot,
            tombstones: tombstones,
            marker: marker
        )
        return output
    }

    func preferredConversation(
        local: MergedConversation,
        cloud: MergedConversation
    ) throws -> MergedConversation {
        guard local.conversation != cloud.conversation || local.data != cloud.data else {
            return MergedConversation(
                conversation: local.conversation,
                data: local.data,
                source: .equivalent,
                localInlineAttachmentData: local.localInlineAttachmentData,
                cloudInlineAttachmentData: cloud.cloudInlineAttachmentData
            )
        }
        let localWins: Bool
        if local.conversation.updatedAt == cloud.conversation.updatedAt {
            localWins = cloud.data.lexicographicallyPrecedes(local.data)
        } else {
            localWins = local.conversation.updatedAt > cloud.conversation.updatedAt
        }
        let winner = localWins ? local : cloud
        try preserveForRecovery(
            localWins ? cloud.data : local.data,
            conversationId: local.conversation.id
        )
        return MergedConversation(
            conversation: winner.conversation,
            data: winner.data,
            source: localWins ? .local : .cloud,
            localInlineAttachmentData: local.localInlineAttachmentData,
            cloudInlineAttachmentData: cloud.cloudInlineAttachmentData
        )
    }

    func resolvedAttachments(
        for merged: [MergedConversation],
        snapshot: ConversationCloudSyncSnapshot
    ) throws -> [CloudAttachmentKey: Data] {
        var result: [CloudAttachmentKey: Data] = [:]
        for item in merged {
            for attachment in item.conversation.messages.flatMap(\.attachments) {
                guard let key = try ConversationAttachmentPath.key(
                    for: attachment,
                    conversationId: item.conversation.id
                ) else { continue }
                if snapshot.attachmentPlaceholders.contains(key) {
                    throw CloudSyncError.requiredDownloadPending
                }
                let localData = try localAttachmentData(for: key)
                let cloudData = snapshot.attachmentData[key]
                let localInlineData = item.localInlineAttachmentData[key]
                let cloudInlineData = item.cloudInlineAttachmentData[key]
                let selectedData: Data?
                switch item.source {
                case .local:
                    selectedData = localInlineData ?? localData ?? cloudInlineData ?? cloudData
                case .cloud, .equivalent:
                    selectedData = cloudInlineData ?? cloudData ?? localInlineData ?? localData
                }
                guard let selectedData else { throw CloudSyncError.missingAttachment }
                for candidate in [localInlineData, localData, cloudInlineData, cloudData].compactMap({ $0 })
                    where candidate != selectedData {
                    try preserveAttachmentForRecovery(candidate, key: key)
                }
                result[key] = selectedData
            }
        }
        return result
    }

    func requireConflictRecoveryDownloads(
        snapshot: ConversationCloudSyncSnapshot,
        merged: [MergedConversation],
        tombstones: [ConversationTombstone],
        marker: ConversationDeleteAllMarker?
    ) throws {
        let retainedKeys = try attachmentKeys(in: merged.map(\.conversation))
        for conversation in snapshot.conversations.values where shouldKeep(
            conversation,
            tombstones: tombstones,
            marker: marker
        ) {
            let removedKeys = try attachmentKeys(in: [conversation]).subtracting(retainedKeys)
            if !removedKeys.isDisjoint(with: snapshot.attachmentPlaceholders) {
                throw CloudSyncError.requiredDownloadPending
            }
        }
    }

    func attachmentKeys(in conversations: [Conversation]) throws -> Set<CloudAttachmentKey> {
        var keys = Set<CloudAttachmentKey>()
        for conversation in conversations {
            for attachment in conversation.messages.flatMap(\.attachments) {
                guard let key = try ConversationAttachmentPath.key(
                    for: attachment,
                    conversationId: conversation.id
                ) else { continue }
                keys.insert(key)
            }
        }
        return keys
    }

    func localConflictAttachmentKeys(
        local: ConversationFiles,
        merged: [MergedConversation],
        tombstones: [ConversationTombstone],
        marker: ConversationDeleteAllMarker?
    ) throws -> Set<CloudAttachmentKey> {
        let mergedById = Dictionary(uniqueKeysWithValues: merged.map { ($0.conversation.id, $0.conversation) })
        var keys = Set<CloudAttachmentKey>()
        for conversation in local.values.values where shouldKeep(
            conversation,
            tombstones: tombstones,
            marker: marker
        ) {
            guard let winner = mergedById[conversation.id], winner != conversation else { continue }
            let winnerKeys = try attachmentKeys(in: [winner])
            keys.formUnion(try storedAttachmentKeys(in: conversation).subtracting(winnerKeys))
        }
        return keys
    }

    func storedAttachmentKeys(in conversation: Conversation) throws -> Set<CloudAttachmentKey> {
        var keys = Set<CloudAttachmentKey>()
        for attachment in conversation.messages.flatMap(\.attachments) {
            if let key = try ConversationAttachmentPath.key(for: attachment) {
                keys.insert(key)
            }
        }
        return keys
    }
}
