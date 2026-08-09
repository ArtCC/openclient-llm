//
//  ConversationTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationTests: XCTestCase {
    // MARK: - Tests

    func test_codable_coloredTags_roundTripPreservesColors() throws {
        // Given
        let conversation = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .blue)]
        )

        // When
        let data = try JSONEncoder().encode(conversation)
        let decoded = try JSONDecoder().decode(Conversation.self, from: data)

        // Then
        XCTAssertEqual(decoded.tags, conversation.tags)
    }

    func test_decode_legacyStringTags_assignsOrangeColor() throws {
        // Given
        let data = try JSONEncoder().encode(Conversation(modelId: "gpt-4"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["tags"] = ["legacy"]
        object.removeValue(forKey: "tagColors")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        // When
        let conversation = try JSONDecoder().decode(Conversation.self, from: legacyData)

        // Then
        XCTAssertEqual(conversation.tags, [ConversationTag(name: "legacy", color: .orange)])
    }

    func test_decode_unknownTagColor_assignsOrangeColor() throws {
        // Given
        let conversation = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "future", color: .blue)]
        )
        let data = try JSONEncoder().encode(conversation)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["tagColors"] = ["future": "pink"]
        let futureData = try JSONSerialization.data(withJSONObject: object)

        // When
        let decoded = try JSONDecoder().decode(Conversation.self, from: futureData)

        // Then
        XCTAssertEqual(decoded.tags, [ConversationTag(name: "future", color: .orange)])
    }

    func test_decode_legacyMessageWithoutFavourite_assignsFalse() throws {
        // Given
        let conversation = Conversation(
            modelId: "gpt-4",
            messages: [ChatMessage(role: .user, content: "Hello")]
        )
        let data = try JSONEncoder().encode(conversation)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        messages[0].removeValue(forKey: "isFavourite")
        object["messages"] = messages
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        // When
        let decoded = try JSONDecoder().decode(Conversation.self, from: legacyData)

        // Then
        XCTAssertFalse(try XCTUnwrap(decoded.messages.first).isFavourite)
    }
}
