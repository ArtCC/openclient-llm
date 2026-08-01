//
//  WidgetSnapshotTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class WidgetSnapshotTests: XCTestCase {
    // MARK: - Properties

    private var sut: ConversationRepository!
    private var settingsManager: MockSettingsManager!
    private var directory: URL!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsManager = MockSettingsManager()
        sut = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        _ = AppGroupStore.clearConversations()
    }

    override func tearDown() async throws {
        _ = AppGroupStore.clearConversations()
        try? FileManager.default.removeItem(at: directory)
        sut = nil
        settingsManager = nil
        directory = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_loadAll_existingLocalConversations_rebuildsWidgetSnapshot() throws {
        // Given
        let conversations = (0..<7).map { index in
            Conversation(
                title: "Conversation \(index)",
                modelId: "model",
                isPinned: index == 0,
                updatedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        try conversations.forEach { try saveLocally($0) }

        // When
        _ = try sut.loadAll()

        // Then
        let snapshot = AppGroupStore.loadConversations()
        XCTAssertEqual(snapshot.map(\.id), conversations.reversed().prefix(6).map(\.id))
        XCTAssertEqual(AppGroupStore.loadPinnedConversations().map(\.id), [conversations[0].id])
    }

    func test_saveConversations_unchangedSnapshot_doesNotWriteAgain() {
        // Given
        let conversation = WidgetConversation(
            id: UUID(),
            title: "Conversation",
            modelId: "model",
            lastMessagePreview: "Preview",
            updatedAt: Date()
        )

        // When
        let firstWriteChanged = AppGroupStore.saveConversations([conversation])
        let secondWriteChanged = AppGroupStore.saveConversations([conversation])

        // Then
        XCTAssertTrue(firstWriteChanged)
        XCTAssertFalse(secondWriteChanged)
    }

    func test_savePinnedConversations_unchangedSnapshot_doesNotWriteAgain() {
        // Given
        let conversation = WidgetConversation(
            id: UUID(),
            title: "Pinned conversation",
            modelId: "model",
            lastMessagePreview: "Preview",
            updatedAt: Date(),
            isPinned: true
        )

        // When
        let firstWriteChanged = AppGroupStore.savePinnedConversations([conversation])
        let secondWriteChanged = AppGroupStore.savePinnedConversations([conversation])

        // Then
        XCTAssertTrue(firstWriteChanged)
        XCTAssertFalse(secondWriteChanged)
    }
}

// MARK: - Private

private extension WidgetSnapshotTests {
    func saveLocally(_ conversation: Conversation) throws {
        let conversationsDirectory = directory.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conversation)
        let fileURL = conversationsDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }
}
