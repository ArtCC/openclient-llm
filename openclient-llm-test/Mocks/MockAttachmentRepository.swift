//
//  MockAttachmentRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Repository tests access an injected instance serially through one ConversationStorage actor.
// Other tests access their instance only from serialized @MainActor test methods.
final class MockAttachmentRepository: AttachmentRepositoryProtocol, @unchecked Sendable {
    // MARK: - Supporting Types

    struct SaveRecord {
        let data: Data
        let attachment: ChatMessage.Attachment
        let conversationId: UUID
    }

    // MARK: - Properties

    var savedAttachments: [SaveRecord] = []
    var saveResult: Result<String, Error> = .success("Attachments/test-conv/test-att.jpg")
    var saveHandler: ((ChatMessage.Attachment, UUID) throws -> String)?
    var loadedData: Data = Data()
    var loadHandler: ((ChatMessage.Attachment) throws -> Data)?
    var loadError: Error?
    var deletedAttachments: [ChatMessage.Attachment] = []
    var deleteError: Error?
    var deleteAllConversationIds: [UUID] = []
    var deleteAllError: Error?
    var deleteAllCalled = false

    // MARK: - Save

    func save(
        data: Data,
        for attachment: ChatMessage.Attachment,
        conversationId: UUID
    ) throws -> String {
        savedAttachments.append(SaveRecord(data: data, attachment: attachment, conversationId: conversationId))
        loadedData = data
        if let saveHandler {
            return try saveHandler(attachment, conversationId)
        }
        switch saveResult {
        case .success(let path): return path
        case .failure(let error): throw error
        }
    }

    // MARK: - Load

    func load(attachment: ChatMessage.Attachment) throws -> Data {
        if let error = loadError { throw error }
        if let loadHandler { return try loadHandler(attachment) }
        return loadedData
    }

    // MARK: - Delete

    func delete(attachment: ChatMessage.Attachment) throws {
        if let error = deleteError { throw error }
        deletedAttachments.append(attachment)
    }

    func deleteAll(forConversationId conversationId: UUID) throws {
        if let deleteAllError { throw deleteAllError }
        deleteAllConversationIds.append(conversationId)
    }

    func deleteAll() throws {
        deleteAllCalled = true
    }
}
