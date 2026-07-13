//
//  ImportConversationsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ImportConversationsUseCaseProtocol: Sendable {
    func execute(_ data: Data) throws -> ImportConversationsResult
}

struct ImportConversationsUseCase: ImportConversationsUseCaseProtocol {
    // MARK: - Properties

    private let saveConversationUseCase: SaveConversationUseCaseProtocol
    private let deleteConversationUseCase: DeleteConversationUseCaseProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(
        saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase(),
        deleteConversationUseCase: DeleteConversationUseCaseProtocol = DeleteConversationUseCase(),
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository()
    ) {
        self.saveConversationUseCase = saveConversationUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.attachmentRepository = attachmentRepository
    }

    // MARK: - Execute

    func execute(_ data: Data) throws -> ImportConversationsResult {
        let document = try decodeDocument(from: data)
        try validate(document)
        let context = ImportContext(
            conversationIds: makeConversationIds(for: document),
            messageIds: makeMessageIds(for: document),
            attachmentData: makeAttachmentData(for: document)
        )
        return try importDocument(document, context: context)
    }
}

// MARK: - Private

private extension ImportConversationsUseCase {
    typealias AttachmentData = [UUID: [UUID: String]]

    struct ImportContext {
        let conversationIds: [UUID: UUID]
        let messageIds: [UUID: UUID]
        let attachmentData: AttachmentData
    }

    struct RestoredConversation {
        let conversation: Conversation
        let attachments: [ChatMessage.Attachment]
        let skippedAttachmentCount: Int
    }

    struct AttachmentRestoration {
        var saved: [ChatMessage.Attachment] = []
        var skippedCount = 0
    }

    func decodeDocument(from data: Data) throws -> ConversationExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let document = try decoder.decode(ConversationExportDocument.self, from: data)
            guard document.format == ConversationExportDocument.formatIdentifier else {
                throw ImportConversationsError.unsupportedFormat
            }
            guard document.version == ConversationExportDocument.currentVersion else {
                throw ImportConversationsError.unsupportedVersion
            }
            return document
        } catch let error as ImportConversationsError {
            throw error
        } catch {
            throw ImportConversationsError.invalidDocument
        }
    }

    func validate(_ document: ConversationExportDocument) throws {
        let conversationIds = document.conversations.map(\.conversation.id)
        guard Set(conversationIds).count == conversationIds.count else {
            throw ImportConversationsError.duplicateConversationIdentifier
        }
        let messageIds = document.conversations.flatMap { $0.conversation.messages.map(\.id) }
        guard Set(messageIds).count == messageIds.count else {
            throw ImportConversationsError.duplicateMessageIdentifier
        }
        try validateAttachmentReferences(in: document)
    }

    func validateAttachmentReferences(in document: ConversationExportDocument) throws {
        var attachmentIds = [UUID: Set<UUID>]()
        for exportedConversation in document.conversations {
            for message in exportedConversation.conversation.messages {
                attachmentIds[message.id] = Set(message.attachments.map(\.id))
            }
        }
        var payloadIds = [UUID: Set<UUID>]()
        for exportedConversation in document.conversations {
            for attachment in exportedConversation.attachments {
                guard attachmentIds[attachment.messageId]?.contains(attachment.attachmentId) == true else {
                    throw ImportConversationsError.invalidAttachmentReference
                }
                guard payloadIds[attachment.messageId, default: []].insert(attachment.attachmentId).inserted else {
                    throw ImportConversationsError.duplicateAttachmentPayload
                }
            }
        }
    }

    func makeConversationIds(for document: ConversationExportDocument) -> [UUID: UUID] {
        Dictionary(uniqueKeysWithValues: document.conversations.map { exportedConversation in
            (exportedConversation.conversation.id, UUID())
        })
    }

    func makeMessageIds(for document: ConversationExportDocument) -> [UUID: UUID] {
        Dictionary(uniqueKeysWithValues: document.conversations.flatMap { exportedConversation in
            exportedConversation.conversation.messages.map { ($0.id, UUID()) }
        })
    }

    func makeAttachmentData(for document: ConversationExportDocument) -> AttachmentData {
        document.conversations.reduce(into: [:]) { data, exportedConversation in
            for attachment in exportedConversation.attachments {
                data[attachment.messageId, default: [:]][attachment.attachmentId] = attachment.data
            }
        }
    }

    func importDocument(
        _ document: ConversationExportDocument,
        context: ImportContext
    ) throws -> ImportConversationsResult {
        var result = ImportConversationsResult(
            importedConversationCount: 0,
            restoredAttachmentCount: 0,
            skippedAttachmentCount: 0
        )
        var savedConversationIds: [UUID] = []
        do {
            for exportedConversation in document.conversations {
                guard let conversationId = context.conversationIds[exportedConversation.conversation.id] else {
                    throw ImportConversationsError.invalidDocument
                }
                let imported = try importConversation(exportedConversation, context: context)
                savedConversationIds.append(conversationId)
                result = ImportConversationsResult(
                    importedConversationCount: result.importedConversationCount + 1,
                    restoredAttachmentCount: result.restoredAttachmentCount + imported.restoredAttachmentCount,
                    skippedAttachmentCount: result.skippedAttachmentCount + imported.skippedAttachmentCount
                )
            }
        } catch {
            rollbackConversations(savedConversationIds)
            throw error
        }
        return result
    }

    func rollbackConversations(_ conversationIds: [UUID]) {
        conversationIds.reversed().forEach { try? deleteConversationUseCase.execute($0) }
    }

    func importConversation(
        _ exportedConversation: ConversationExportDocument.ExportedConversation,
        context: ImportContext
    ) throws -> (restoredAttachmentCount: Int, skippedAttachmentCount: Int) {
        let restored = try restoreConversation(
            exportedConversation.conversation,
            context: context
        )
        do {
            try saveConversationUseCase.execute(restored.conversation)
            return (restored.attachments.count, restored.skippedAttachmentCount)
        } catch {
            restored.attachments.forEach { try? attachmentRepository.delete(attachment: $0) }
            throw error
        }
    }

    func restoreConversation(
        _ conversation: Conversation,
        context: ImportContext
    ) throws -> RestoredConversation {
        guard let conversationId = context.conversationIds[conversation.id] else {
            throw ImportConversationsError.invalidDocument
        }
        var attachmentRestoration = AttachmentRestoration()
        let messages: [ChatMessage]
        do {
            messages = try conversation.messages.map { message in
                try restoreMessage(
                    message,
                    conversationId: conversationId,
                    context: context,
                    attachmentRestoration: &attachmentRestoration
                )
            }
        } catch {
            attachmentRestoration.saved.forEach { try? attachmentRepository.delete(attachment: $0) }
            throw error
        }
        return RestoredConversation(
            conversation: Conversation(
                id: conversationId,
                title: conversation.title,
                modelId: conversation.modelId,
                systemPrompt: conversation.systemPrompt,
                messages: messages,
                modelParameters: conversation.modelParameters,
                isPinned: conversation.isPinned,
                tags: conversation.tags,
                parentConversationId: conversation.parentConversationId.flatMap { context.conversationIds[$0] },
                branchedFromMessageId: conversation.branchedFromMessageId.flatMap { context.messageIds[$0] },
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt
            ),
            attachments: attachmentRestoration.saved,
            skippedAttachmentCount: attachmentRestoration.skippedCount
        )
    }

    func restoreMessage(
        _ message: ChatMessage,
        conversationId: UUID,
        context: ImportContext,
        attachmentRestoration: inout AttachmentRestoration
    ) throws -> ChatMessage {
        guard let messageId = context.messageIds[message.id] else {
            throw ImportConversationsError.invalidDocument
        }
        let attachments = try restoreAttachments(
            message.attachments,
            messageId: message.id,
            conversationId: conversationId,
            context: context,
            attachmentRestoration: &attachmentRestoration
        )
        return ChatMessage(
            id: messageId,
            role: message.role,
            content: message.content,
            reasoningContent: message.reasoningContent,
            timestamp: message.timestamp,
            attachments: attachments,
            tokenUsage: message.tokenUsage,
            webSearchResults: message.webSearchResults,
            toolCalls: message.toolCalls,
            toolCallId: message.toolCallId,
            toolName: message.toolName,
            isFavourite: message.isFavourite
        )
    }

    func restoreAttachments(
        _ attachments: [ChatMessage.Attachment],
        messageId: UUID,
        conversationId: UUID,
        context: ImportContext,
        attachmentRestoration: inout AttachmentRestoration
    ) throws -> [ChatMessage.Attachment] {
        try attachments.compactMap { attachment in
            guard let encodedData = context.attachmentData[messageId]?[attachment.id],
                  let data = Data(base64Encoded: encodedData) else {
                attachmentRestoration.skippedCount += 1
                return nil
            }
            let importedAttachment = ChatMessage.Attachment(
                id: UUID(),
                type: attachment.type,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                fileRelativePath: ""
            )
            let path = try attachmentRepository.save(
                data: data,
                for: importedAttachment,
                conversationId: conversationId
            )
            let persistedAttachment = ChatMessage.Attachment(
                id: importedAttachment.id,
                type: importedAttachment.type,
                fileName: importedAttachment.fileName,
                mimeType: importedAttachment.mimeType,
                fileRelativePath: path
            )
            attachmentRestoration.saved.append(persistedAttachment)
            return persistedAttachment
        }
    }
}

private enum ImportConversationsError: LocalizedError {
    case invalidDocument
    case unsupportedFormat
    case unsupportedVersion
    case duplicateConversationIdentifier
    case duplicateMessageIdentifier
    case invalidAttachmentReference
    case duplicateAttachmentPayload

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            String(localized: "The backup file is invalid.")
        case .unsupportedFormat:
            String(localized: "This file is not an OpenClient backup.")
        case .unsupportedVersion:
            String(localized: "This backup version is not supported.")
        case .duplicateConversationIdentifier, .duplicateMessageIdentifier, .duplicateAttachmentPayload:
            String(localized: "The backup contains duplicate identifiers.")
        case .invalidAttachmentReference:
            String(localized: "The backup contains an invalid attachment reference.")
        }
    }
}
