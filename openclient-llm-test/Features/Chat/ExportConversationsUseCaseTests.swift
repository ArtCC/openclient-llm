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

    func test_execute_backup_exportsAllStoredConversations() throws {
        // Given
        let conversations = [Conversation(modelId: "gpt-4"), Conversation(modelId: "llama3")]
        let loadConversations = MockLoadConversationsUseCase()
        loadConversations.result = .success(conversations)
        let sut = ExportBackupUseCase(loadConversationsUseCase: loadConversations)

        // When
        let data = try sut.execute()
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
}
