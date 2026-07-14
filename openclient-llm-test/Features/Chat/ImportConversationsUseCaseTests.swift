//
//  ImportConversationsUseCaseTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ImportConversationsUseCaseTests: XCTestCase {
    // MARK: - Properties

    var mockSaveConversation: MockSaveConversationUseCase!
    var mockDeleteConversation: MockDeleteConversationUseCase!
    var mockLoadConversations: MockLoadConversationsUseCase!
    var mockAttachmentRepository: MockAttachmentRepository!
    var sut: ImportConversationsUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockSaveConversation = MockSaveConversationUseCase()
        mockDeleteConversation = MockDeleteConversationUseCase()
        mockLoadConversations = MockLoadConversationsUseCase()
        mockAttachmentRepository = MockAttachmentRepository()
        sut = ImportConversationsUseCase(
            saveConversationUseCase: mockSaveConversation,
            deleteConversationUseCase: mockDeleteConversation,
            loadConversationsUseCase: mockLoadConversations,
            attachmentRepository: mockAttachmentRepository
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAttachmentRepository = nil
        mockLoadConversations = nil
        mockDeleteConversation = nil
        mockSaveConversation = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_validDocument_restoresConversationWithNewIdentifiers() throws {
        // Given
        let attachment = makeAttachment()
        let message = ChatMessage(role: .user, content: "Hello", attachments: [attachment])
        let conversation = Conversation(modelId: "gpt-4", messages: [message])
        let document = ConversationExportDocument(conversations: [
            .init(
                conversation: conversation,
                attachments: [.init(messageId: message.id, attachmentId: attachment.id, data: "hello".base64Encoded)]
            )
        ])

        // When
        let result = try sut.execute(try encoded(document))

        // Then
        let imported = try XCTUnwrap(mockSaveConversation.savedConversations.first)
        XCTAssertEqual(result.importedConversationCount, 1)
        XCTAssertEqual(result.restoredAttachmentCount, 1)
        XCTAssertNotEqual(imported.id, conversation.id)
        XCTAssertNotEqual(imported.messages[0].id, message.id)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.first?.data, Data("hello".utf8))
        XCTAssertFalse(imported.messages[0].attachments[0].fileRelativePath.isEmpty)
    }

    func test_execute_invalidAttachmentData_importsConversationWithoutAttachment() throws {
        // Given
        let attachment = makeAttachment()
        let message = ChatMessage(role: .user, content: "Hello", attachments: [attachment])
        let conversation = Conversation(modelId: "gpt-4", messages: [message])
        let document = ConversationExportDocument(conversations: [
            .init(
                conversation: conversation,
                attachments: [.init(messageId: message.id, attachmentId: attachment.id, data: "invalid base64")]
            )
        ])

        // When
        let result = try sut.execute(try encoded(document))

        // Then
        XCTAssertEqual(result.importedConversationCount, 1)
        XCTAssertEqual(result.skippedAttachmentCount, 1)
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
        XCTAssertTrue(mockSaveConversation.savedConversations[0].messages[0].attachments.isEmpty)
    }

    func test_execute_invalidAttachmentReference_throwsWithoutPersisting() throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        let document = ConversationExportDocument(conversations: [
            .init(
                conversation: conversation,
                attachments: [.init(messageId: UUID(), attachmentId: UUID(), data: "data")]
            )
        ])

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertTrue(mockSaveConversation.savedConversations.isEmpty)
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
    }

    func test_execute_saveConversationFails_deletesRestoredAttachments() throws {
        // Given
        let attachment = makeAttachment()
        let message = ChatMessage(role: .user, content: "Hello", attachments: [attachment])
        let document = ConversationExportDocument(conversations: [
            .init(
                conversation: Conversation(modelId: "gpt-4", messages: [message]),
                attachments: [.init(messageId: message.id, attachmentId: attachment.id, data: "hello".base64Encoded)]
            )
        ])
        mockSaveConversation.error = NSError(domain: "test", code: 1)

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertEqual(mockAttachmentRepository.deletedAttachments.count, 1)
    }

    func test_execute_branchedConversations_remapsBranchReferences() throws {
        // Given
        let rootMessage = ChatMessage(role: .user, content: "Root")
        let root = Conversation(modelId: "gpt-4", messages: [rootMessage])
        let branch = Conversation(
            modelId: "gpt-4",
            parentConversationId: root.id,
            branchedFromMessageId: rootMessage.id
        )
        let document = ConversationExportDocument(conversations: [
            .init(conversation: root, attachments: []),
            .init(conversation: branch, attachments: [])
        ])

        // When
        _ = try sut.execute(try encoded(document))

        // Then
        let importedRoot = mockSaveConversation.savedConversations[0]
        let importedBranch = mockSaveConversation.savedConversations[1]
        XCTAssertEqual(importedBranch.parentConversationId, importedRoot.id)
        XCTAssertEqual(importedBranch.branchedFromMessageId, importedRoot.messages[0].id)
    }

    func test_execute_laterSaveFails_rollsBackPreviouslySavedConversations() throws {
        // Given
        let document = ConversationExportDocument(conversations: [
            .init(conversation: Conversation(modelId: "gpt-4"), attachments: []),
            .init(conversation: Conversation(modelId: "llama3"), attachments: [])
        ])
        mockSaveConversation.failureAtCall = 2

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertEqual(mockDeleteConversation.deletedIds.count, 1)
    }

    func test_execute_summaryWithoutCursor_throwsWithoutPersisting() throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4", contextSummary: "Summary")
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertTrue(mockSaveConversation.savedConversations.isEmpty)
    }

    func test_execute_cursorOutsideConversation_throwsWithoutPersisting() throws {
        // Given
        let conversation = Conversation(
            modelId: "gpt-4",
            contextSummary: "Summary",
            contextSummaryCursorMessageId: UUID(),
            messages: [ChatMessage(role: .user, content: "Hello")]
        )
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertTrue(mockSaveConversation.savedConversations.isEmpty)
    }

    func test_execute_nonPositiveContextWindow_throwsWithoutPersisting() throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4", contextWindowTokens: 0)
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertTrue(mockSaveConversation.savedConversations.isEmpty)
    }

    func test_execute_validSummaryAndCursor_remapsCursor() throws {
        // Given
        let message = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(
            modelId: "gpt-4",
            contextSummary: "Summary",
            contextSummaryCursorMessageId: message.id,
            messages: [message]
        )
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When
        _ = try sut.execute(try encoded(document))

        // Then
        let imported = try XCTUnwrap(mockSaveConversation.savedConversations.first)
        XCTAssertEqual(imported.contextSummaryCursorMessageId, imported.messages.first?.id)
    }

    func test_execute_cursorInsideToolRound_throwsWithoutPersisting() throws {
        // Given
        let call = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "search", arguments: "{}")
        )
        let assistant = ChatMessage(role: .assistant, content: "", toolCalls: [call])
        let tool = ChatMessage(role: .tool, content: "Result", toolCallId: call.id, toolName: "search")
        let conversation = Conversation(
            modelId: "gpt-4",
            contextSummary: "Summary",
            contextSummaryCursorMessageId: assistant.id,
            messages: [assistant, tool]
        )
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When / Then
        XCTAssertThrowsError(try sut.execute(try encoded(document)))
        XCTAssertTrue(mockSaveConversation.savedConversations.isEmpty)
    }

    func test_execute_tagAlreadyExistsLocally_reusesLocalColor() throws {
        // Given
        mockLoadConversations.result = .success([
            Conversation(
                modelId: "gpt-4",
                tags: [ConversationTag(name: "swift", color: .blue)]
            )
        ])
        let conversation = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .red)]
        )
        let document = ConversationExportDocument(conversations: [
            .init(conversation: conversation, attachments: [])
        ])

        // When
        _ = try sut.execute(try encoded(document))

        // Then
        XCTAssertEqual(
            mockSaveConversation.savedConversations.first?.tags,
            [ConversationTag(name: "swift", color: .blue)]
        )
    }
}

// MARK: - Private

private extension ImportConversationsUseCaseTests {
    func makeAttachment() -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            type: .pdf,
            fileName: "document.pdf",
            mimeType: "application/pdf",
            fileRelativePath: "Attachments/original/document.pdf"
        )
    }

    func encoded(_ document: ConversationExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }
}

private extension String {
    var base64Encoded: String {
        Data(utf8).base64EncodedString()
    }
}
