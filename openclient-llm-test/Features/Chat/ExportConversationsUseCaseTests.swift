//
//  ExportConversationsUseCaseTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ExportConversationsUseCaseTests: XCTestCase {
    // MARK: - Tests

    func test_execute_multipleConversations_exportsSingleVersionedDocument() throws {
        // Given
        let date = Date(timeIntervalSince1970: 0)
        let conversations = [
            Conversation(modelId: "gpt-4", createdAt: date, updatedAt: date),
            Conversation(modelId: "llama3", createdAt: date, updatedAt: date)
        ]
        let sut = ExportConversationsUseCase()

        // When
        let data = try sut.execute(conversations)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConversationExportDocument.self, from: data)

        // Then
        XCTAssertEqual(document.format, ConversationExportDocument.formatIdentifier)
        XCTAssertEqual(document.version, ConversationExportDocument.currentVersion)
        XCTAssertEqual(document.conversations.map(\.conversation), conversations)
    }

    func test_execute_backup_exportsAllStoredConversations() async throws {
        // Given
        let conversations = [Conversation(modelId: "gpt-4"), Conversation(modelId: "llama3")]
        let loadConversations = MockLoadConversationsUseCase()
        loadConversations.result = .success(conversations)
        let sut = ExportBackupUseCase(loadConversationsUseCase: loadConversations)

        // When
        let data = try await sut.execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConversationExportDocument.self, from: data)

        // Then
        XCTAssertEqual(document.conversations.count, conversations.count)
        XCTAssertEqual(document.conversations.map(\.conversation.modelId), ["gpt-4", "llama3"])
    }

    func test_execute_invalidContextMetadata_throwsBeforeEncoding() {
        // Given
        let conversation = Conversation(modelId: "gpt-4", contextSummary: "Summary")
        let sut = ExportConversationsUseCase()

        // When / Then
        XCTAssertThrowsError(try sut.execute([conversation]))
    }

    func test_execute_validContextMetadata_preservesIt() throws {
        // Given
        let message = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(
            modelId: "gpt-4",
            contextWindowTokens: 8_192,
            contextSummary: "Summary",
            contextSummaryCursorMessageId: message.id,
            messages: [message]
        )
        let sut = ExportConversationsUseCase()

        // When
        let data = try sut.execute([conversation])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConversationExportDocument.self, from: data)

        // Then
        let exported = try XCTUnwrap(document.conversations.first?.conversation)
        XCTAssertEqual(exported.contextWindowTokens, 8_192)
        XCTAssertEqual(exported.contextSummary, "Summary")
        XCTAssertEqual(exported.contextSummaryCursorMessageId, message.id)
    }

    func test_execute_attachmentWithTransientAndStoredData_exportsTransientData() throws {
        // Given
        let transientData = Data([0x01, 0x02])
        let attachmentRepository = MockAttachmentRepository()
        attachmentRepository.loadedData = Data([0x03, 0x04])
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/image.png",
            transientData: transientData
        )
        let message = ChatMessage(role: .assistant, content: "Image", attachments: [attachment])
        let sut = ExportConversationsUseCase(attachmentRepository: attachmentRepository)

        // When
        let data = try sut.execute([Conversation(modelId: "gpt-4", messages: [message])])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConversationExportDocument.self, from: data)

        // Then
        XCTAssertEqual(document.conversations.first?.attachments.first?.data, transientData.base64EncodedString())
    }

    func test_execute_attachmentWithoutReadableSource_omitsAttachmentPayload() throws {
        // Given
        let attachmentRepository = MockAttachmentRepository()
        attachmentRepository.loadError = NSError(domain: "ExportConversationsUseCaseTests", code: 1)
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "missing.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/missing.png"
        )
        let message = ChatMessage(role: .assistant, content: "Missing", attachments: [attachment])
        let sut = ExportConversationsUseCase(attachmentRepository: attachmentRepository)

        // When
        let data = try sut.execute([Conversation(modelId: "gpt-4", messages: [message])])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConversationExportDocument.self, from: data)

        // Then
        XCTAssertTrue(document.conversations.first?.attachments.isEmpty == true)
    }

    func test_execute_normalBranchBackup_importsNonEmptyConversations() async throws {
        // Given
        let first = ChatMessage(role: .user, content: "Question")
        let second = ChatMessage(role: .assistant, content: "Answer")
        let root = Conversation(
            modelId: "gpt-4",
            contextSummary: "Question and answer",
            contextSummaryCursorMessageId: second.id,
            messages: [first, second]
        )
        let branch = try await BranchConversationUseCase(
            saveConversationUseCase: MockSaveConversationUseCase(),
            attachmentRepository: MockAttachmentRepository()
        ).execute(conversation: root, fromMessageId: second.id)
        let backup = try ExportConversationsUseCase().execute([root, branch])
        let saveImport = MockSaveConversationUseCase()
        let importUseCase = ImportConversationsUseCase(
            saveConversationUseCase: saveImport,
            loadConversationsUseCase: MockLoadConversationsUseCase()
        )

        // When
        let result = try await importUseCase.execute(backup)

        // Then
        XCTAssertEqual(result.importedConversationCount, 2)
        XCTAssertEqual(saveImport.savedConversations.map(\.messages.count), [2, 2])
        XCTAssertEqual(
            saveImport.savedConversations[1].contextSummaryCursorMessageId,
            saveImport.savedConversations[1].messages[1].id
        )
        XCTAssertEqual(
            saveImport.savedConversations[1].branchedFromMessageId,
            saveImport.savedConversations[0].messages[1].id
        )
    }
}
