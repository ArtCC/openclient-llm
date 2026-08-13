//
//  ConversationRepositorySyncTests+DeletionVisibility.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension ConversationRepositorySyncTests {
    func test_loadLocal_tombstoneWrittenBeforePayloadRemoval_hidesDeletedConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let tombstone = ConversationTombstone(
            conversationId: conversation.id,
            deletedAt: conversation.updatedAt.addingTimeInterval(1)
        )
        try SyncJSONCoding.makeEncoder().encode([tombstone]).write(
            to: directory.appendingPathComponent("ConversationTombstones.json"),
            options: .atomic
        )

        // When
        let conversations = try await sut.loadLocal()

        // Then
        XCTAssertTrue(conversations.isEmpty)
        let payloadURL = directory
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL.path))
    }

    func staleLocalAndNewerCloudConversation() -> (local: Conversation, cloud: Conversation) {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let local = Conversation(
            id: id,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Local")],
            updatedAt: timestamp
        )
        let cloud = Conversation(
            id: id,
            modelId: "model",
            messages: local.messages + [ChatMessage(role: .assistant, content: "Cloud")],
            updatedAt: timestamp.addingTimeInterval(1)
        )
        return (local, cloud)
    }
}
