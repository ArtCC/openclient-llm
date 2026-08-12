//
//  ConversationStorage+Merge.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Merge

extension ConversationStorage {
    func shouldKeep(
        _ conversation: Conversation,
        tombstones: [ConversationTombstone],
        marker: ConversationDeleteAllMarker?
    ) -> Bool {
        let tombstoneDate = tombstones
            .filter { $0.conversationId == conversation.id }
            .map(\.deletedAt)
            .max()
        if let tombstoneDate, conversation.updatedAt <= tombstoneDate {
            return false
        }
        if let marker, conversation.updatedAt <= marker.deletedAt {
            return false
        }
        return true
    }

    struct MergeContext {
        let local: ConversationFiles
        let snapshot: ConversationCloudSyncSnapshot
        let tombstones: [ConversationTombstone]
        let deleteAllMarker: ConversationDeleteAllMarker?
        let pendingMutationBases: [UUID: Conversation]
        let localAttachmentData: [CloudAttachmentKey: Data]
    }

    struct PendingMergeContext {
        let localCandidate: MergedConversation?
        let cloudCandidate: MergedConversation?
        let localConversation: Conversation
        let localData: Data
        let pendingBase: Conversation
        let mergeContext: MergeContext
    }

    func mergeConversations(context: MergeContext) throws -> [MergedConversation] {
        let ids = Set(context.local.values.keys)
            .union(context.snapshot.conversations.keys)
            .sorted { $0.uuidString < $1.uuidString }
        return try ids.compactMap { try mergedConversation(id: $0, context: context) }.sorted {
            if $0.conversation.updatedAt != $1.conversation.updatedAt {
                return $0.conversation.updatedAt > $1.conversation.updatedAt
            }
            return $0.conversation.id.uuidString < $1.conversation.id.uuidString
        }
    }

    func mergedConversation(id: UUID, context: MergeContext) throws -> MergedConversation? {
        let localCandidate = try localCandidate(id: id, context: context)
        let cloudCandidate = try cloudCandidate(id: id, context: context)
        if let pendingBase = context.pendingMutationBases[id],
           let localConversation = context.local.values[id],
           let localData = context.local.data[id] {
            return try mergePendingConversation(context: PendingMergeContext(
                localCandidate: localCandidate,
                cloudCandidate: cloudCandidate,
                localConversation: localConversation,
                localData: localData,
                pendingBase: pendingBase,
                mergeContext: context
            ))
        }
        if let localCandidate, let cloudCandidate {
            return try preferredConversation(local: localCandidate, cloud: cloudCandidate)
        }
        return localCandidate ?? cloudCandidate
    }

    func mergePendingConversation(context: PendingMergeContext) throws -> MergedConversation? {
        guard shouldKeep(
            context.pendingBase,
            tombstones: context.mergeContext.tombstones,
            marker: context.mergeContext.deleteAllMarker
        ) else {
            try preservePendingConversationForRecovery(
                context.localConversation,
                data: context.localData,
                attachmentData: context.mergeContext.localAttachmentData
            )
            return context.cloudCandidate
        }
        guard let localCandidate = context.localCandidate else {
            throw CloudSyncError.invalidConversationData
        }
        do {
            return try rebasedPendingConversation(
                local: localCandidate,
                localConversation: context.localConversation,
                base: context.pendingBase,
                cloud: context.cloudCandidate
            )
        } catch {
            try preserveForRecovery(context.localData, conversationId: context.localConversation.id)
            if let cloudCandidate = context.cloudCandidate {
                try preserveForRecovery(cloudCandidate.data, conversationId: context.localConversation.id)
            }
            throw error
        }
    }

    func localCandidate(id: UUID, context: MergeContext) throws -> MergedConversation? {
        guard let conversation = context.local.values[id],
              context.pendingMutationBases[id] != nil || shouldKeep(
                  conversation,
                  tombstones: context.tombstones,
                  marker: context.deleteAllMarker
              ) else {
            return nil
        }
        guard let data = context.local.data[id] else { throw CloudSyncError.invalidConversationData }
        return try makeMergedConversation(
            conversation: conversation,
            data: data,
            source: .local,
            normalizationContext: AttachmentNormalizationContext(
                sourceData: context.localAttachmentData,
                sourcePlaceholders: [],
                knownConversationIds: Set(context.local.values.keys)
            )
        )
    }

    func cloudCandidate(id: UUID, context: MergeContext) throws -> MergedConversation? {
        guard let conversation = context.snapshot.conversations[id],
              shouldKeep(
                  conversation,
                  tombstones: context.tombstones,
                  marker: context.deleteAllMarker
              ) else {
            return nil
        }
        guard let data = context.snapshot.conversationData[id] else {
            throw CloudSyncError.invalidConversationData
        }
        return try makeMergedConversation(
            conversation: conversation,
            data: data,
            source: .cloud,
            normalizationContext: AttachmentNormalizationContext(
                sourceData: context.snapshot.attachmentData,
                sourcePlaceholders: context.snapshot.attachmentPlaceholders,
                knownConversationIds: Set(context.snapshot.conversations.keys)
            )
        )
    }

    func rebasedPendingConversation(
        local: MergedConversation,
        localConversation: Conversation,
        base: Conversation,
        cloud: MergedConversation?
    ) throws -> MergedConversation {
        let current = cloud?.conversation ?? base
        var conversation = try rebasedConversation(localConversation, base: base, onto: current)
        guard conversation != current else { return cloud ?? local }
        let latestDate = [localConversation.updatedAt, current.updatedAt, base.updatedAt].max()
        conversation.updatedAt = nextModificationDate(after: latestDate)
        let data = try makeEncoder().encode(conversation)
        let canonicalConversation = try makeDecoder().decode(Conversation.self, from: data)
        if let cloud, cloud.data != data {
            try preserveForRecovery(cloud.data, conversationId: conversation.id)
        }
        return MergedConversation(
            conversation: canonicalConversation,
            data: data,
            source: .local,
            localInlineAttachmentData: local.localInlineAttachmentData,
            cloudInlineAttachmentData: cloud?.cloudInlineAttachmentData ?? [:]
        )
    }

    func preservePendingConversationForRecovery(
        _ conversation: Conversation,
        data: Data,
        attachmentData: [CloudAttachmentKey: Data]
    ) throws {
        try preserveForRecovery(data, conversationId: conversation.id)
        for key in try storedAttachmentKeys(in: conversation) {
            if let data = attachmentData[key] {
                try preserveAttachmentForRecovery(data, key: key)
            }
        }
    }
}
