//
//  ExportConversationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ExportConversationUseCaseTests: XCTestCase {
    // MARK: - Properties

    var sut: ExportConversationUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        sut = ExportConversationUseCase()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_returnsValidJSON() throws {
        // Given
        let conversation = Conversation(
            title: "Test Conversation",
            modelId: "gpt-4",
            messages: [
                ChatMessage(role: .user, content: "Hello"),
                ChatMessage(role: .assistant, content: "Hi there!")
            ]
        )

        // When
        let data = try sut.execute(conversation)

        // Then
        XCTAssertFalse(data.isEmpty)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["title"] as? String, "Test Conversation")
        XCTAssertEqual(json?["modelId"] as? String, "gpt-4")
    }

    func test_execute_outputIsPrettyPrinted() throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")

        // When
        let data = try sut.execute(conversation)
        let string = String(data: data, encoding: .utf8) ?? ""

        // Then — pretty-printed JSON contains newlines
        XCTAssertTrue(string.contains("\n"))
    }

    func test_execute_encodesAllMessages() throws {
        // Given
        let messages = (1...5).map { idx in
            ChatMessage(role: idx % 2 == 0 ? .assistant : .user, content: "Message \(idx)")
        }
        let conversation = Conversation(modelId: "gpt-4", messages: messages)

        // When
        let data = try sut.execute(conversation)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Conversation.self, from: data)

        // Then
        XCTAssertEqual(decoded.messages.count, 5)
    }

    func test_execute_roundTrip_preservesConversation() throws {
        // Given
        let original = Conversation(
            title: "Round-trip Test",
            modelId: "llama3",
            systemPrompt: "Be helpful",
            messages: [ChatMessage(role: .user, content: "Test")]
        )

        // When
        let data = try sut.execute(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Conversation.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.modelId, original.modelId)
        XCTAssertEqual(decoded.systemPrompt, original.systemPrompt)
        XCTAssertEqual(decoded.messages.count, original.messages.count)
    }
}
