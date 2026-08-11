//
//  ConversationStorage+ImportBatch.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Import Batch

extension ConversationStorage {
    func importBatch(_ conversations: [Conversation]) throws -> [Conversation] {
        try ensureDirectoryExists()
        let existingIds = Set(try loadLocalConversations().map(\.id))
        let importedIds = conversations.map(\.id)
        guard Set(importedIds).count == importedIds.count,
              importedIds.allSatisfy({ !existingIds.contains($0) }) else {
            throw CloudSyncError.invalidConversationData
        }
        let canonical = try conversations.map(canonicalConversation)
        let attachmentKeys = try canonical.reduce(into: Set<CloudAttachmentKey>()) { keys, item in
            keys.formUnion(try self.attachmentKeys(in: [item.conversation]))
        }
        let verification = ConversationLocalTransaction.Verification(
            conversations: Dictionary(uniqueKeysWithValues: canonical.map { ($0.conversation.id, $0.conversation) }),
            attachments: canonical.reduce(into: [CloudAttachmentKey: Data]()) { data, item in
                data.merge(item.attachmentData) { _, imported in imported }
            }
        )
        let transaction = try ConversationLocalTransaction(
            fileManager: fileManager,
            documentsURL: documentsURL,
            attachmentKeys: attachmentKeys
        )
        do {
            for item in canonical {
                try persistLocalAttachments(item.attachmentData)
                try saveLocal(item.conversation)
            }
            try transaction.commit(verifying: verification)
        } catch {
            try transaction.rollback()
            throw error
        }
        return canonical.map(\.conversation)
    }
}
