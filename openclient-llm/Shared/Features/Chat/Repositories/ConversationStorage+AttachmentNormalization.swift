//
//  ConversationStorage+AttachmentNormalization.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Attachment Normalization

extension ConversationStorage {
    struct AttachmentNormalizationContext {
        let sourceData: [CloudAttachmentKey: Data]
        let sourcePlaceholders: Set<CloudAttachmentKey>
        let knownConversationIds: Set<UUID>
    }

    struct NormalizedAttachment {
        let attachment: ChatMessage.Attachment
        let key: CloudAttachmentKey
        let data: Data?
    }

    func makeMergedConversation(
        conversation: Conversation,
        data: Data,
        source: Source,
        normalizationContext: AttachmentNormalizationContext
    ) throws -> MergedConversation {
        var conversation = conversation
        try conversation.validateContextMetadata()
        let inlineAttachmentData = try normalizeAttachments(
            in: &conversation,
            context: normalizationContext
        )

        let normalizedData: Data
        if !inlineAttachmentData.isEmpty {
            try preserveForRecovery(data, conversationId: conversation.id)
            normalizedData = try makeEncoder().encode(conversation)
        } else {
            normalizedData = data
        }
        return MergedConversation(
            conversation: conversation,
            data: normalizedData,
            source: source,
            localInlineAttachmentData: source == .local ? inlineAttachmentData : [:],
            cloudInlineAttachmentData: source == .cloud ? inlineAttachmentData : [:]
        )
    }

    func normalizeAttachments(
        in conversation: inout Conversation,
        context: AttachmentNormalizationContext
    ) throws -> [CloudAttachmentKey: Data] {
        var inlineAttachmentData: [CloudAttachmentKey: Data] = [:]
        for messageIndex in conversation.messages.indices {
            for attachmentIndex in conversation.messages[messageIndex].attachments.indices {
                let attachment = conversation.messages[messageIndex].attachments[attachmentIndex]
                let normalized = try normalizedAttachment(
                    attachment,
                    conversationId: conversation.id,
                    context: context
                )
                if let attachmentData = normalized.data,
                   let existing = inlineAttachmentData[normalized.key],
                   existing != attachmentData {
                    throw CloudSyncError.invalidConversationData
                }
                if let attachmentData = normalized.data {
                    inlineAttachmentData[normalized.key] = attachmentData
                }
                conversation.messages[messageIndex].attachments[attachmentIndex] = normalized.attachment
            }
        }
        return inlineAttachmentData
    }

    func normalizedAttachment(
        _ attachment: ChatMessage.Attachment,
        conversationId: UUID,
        context: AttachmentNormalizationContext
    ) throws -> NormalizedAttachment {
        guard !attachment.fileRelativePath.isEmpty || attachment.transientData != nil else {
            throw CloudSyncError.missingAttachment
        }
        let sourceKey = try ConversationAttachmentPath.key(for: attachment)
        let key: CloudAttachmentKey
        var data = attachment.transientData
        if let sourceKey, sourceKey.conversationId != conversationId {
            let fileIdentifier = UUID(uuidString: (sourceKey.fileName as NSString).deletingPathExtension)
            guard fileIdentifier == attachment.id,
                  !context.knownConversationIds.contains(sourceKey.conversationId) else {
                throw CloudSyncError.invalidAttachmentPath
            }
            if context.sourcePlaceholders.contains(sourceKey) {
                throw CloudSyncError.requiredDownloadPending
            }
            data = data ?? context.sourceData[sourceKey]
            guard data != nil else { throw CloudSyncError.missingAttachment }
            key = CloudAttachmentKey(conversationId: conversationId, fileName: sourceKey.fileName)
        } else if let sourceKey {
            key = sourceKey
        } else {
            key = try generatedAttachmentKey(attachment, conversationId: conversationId)
        }
        let normalizedAttachment = ChatMessage.Attachment(
            id: attachment.id,
            type: attachment.type,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            fileRelativePath: ConversationAttachmentPath.relativePath(for: key)
        )
        return NormalizedAttachment(attachment: normalizedAttachment, key: key, data: data)
    }

    func generatedAttachmentKey(
        _ attachment: ChatMessage.Attachment,
        conversationId: UUID
    ) throws -> CloudAttachmentKey {
        let relativePath = ConversationAttachmentPath.relativePath(
            for: attachment,
            conversationId: conversationId
        )
        let normalized = ChatMessage.Attachment(
            id: attachment.id,
            type: attachment.type,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            fileRelativePath: relativePath
        )
        guard let key = try ConversationAttachmentPath.key(
            for: normalized,
            conversationId: conversationId
        ) else {
            throw CloudSyncError.invalidAttachmentPath
        }
        return key
    }
}
