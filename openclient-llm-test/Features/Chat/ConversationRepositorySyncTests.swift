//
//  ConversationRepositorySyncTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationRepositorySyncTests: XCTestCase {
    // MARK: - Properties

    private var sut: ConversationRepository!
    private var settingsManager: MockSettingsManager!
    private var cloudSyncManager: MockCloudSyncManager!
    private var directory: URL!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager = MockCloudSyncManager()
        sut = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        sut = nil
        settingsManager = nil
        cloudSyncManager = nil
        directory = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_synchronize_localConversation_uploadsWithoutDeletingIt() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        try sut.save(conversation)

        // When
        let result = sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertTrue(cloudSyncManager.syncedConversations.contains { $0.id == conversation.id })
        XCTAssertEqual(try sut.loadAll().map(\.id), [conversation.id])
    }

    func test_synchronize_cloudConversation_restoresLocally() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        cloudSyncManager.cloudConversations = [conversation]

        // When
        let result = sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertEqual(try sut.loadAll().map(\.id), [conversation.id])
    }

    func test_synchronize_conflict_keepsMostRecentlyUpdatedConversation() throws {
        // Given
        let id = UUID()
        let older = Conversation(id: id, title: "Older", modelId: "model", updatedAt: .distantPast)
        let newer = Conversation(id: id, title: "Newer", modelId: "model", updatedAt: Date())
        settingsManager.isCloudSyncEnabled = false
        try sut.save(older)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.cloudConversations = [newer]

        // When
        _ = sut.synchronize()

        // Then
        XCTAssertEqual(try sut.loadAll().first?.title, "Newer")
    }

    func test_delete_offlineTombstone_preventsRemoteConversationFromReturning() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try sut.save(conversation)
        cloudSyncManager.cloudConversations = [
            Conversation(id: conversation.id, modelId: "model", updatedAt: Date().addingTimeInterval(60))
        ]

        // When
        try sut.delete(conversation.id)
        settingsManager.isCloudSyncEnabled = true
        _ = sut.synchronize()

        // Then
        XCTAssertTrue(try sut.loadAll().isEmpty)
        XCTAssertTrue(cloudSyncManager.deletedIds.contains(conversation.id))
    }

    func test_synchronize_pendingPlaceholder_preservesLocalConversation() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.pendingConversationDownloads = true

        // When
        let result = sut.synchronize()

        // Then
        XCTAssertEqual(result, .pendingDownload)
        XCTAssertEqual(try sut.loadAll().map(\.id), [conversation.id])
    }

    func test_deleteAll_syncDisabled_doesNotDeleteCloudConversationsLater() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try sut.save(conversation)
        cloudSyncManager.cloudConversations = [conversation]

        // When
        try sut.deleteAll()
        settingsManager.isCloudSyncEnabled = true
        _ = sut.synchronize()

        // Then
        XCTAssertEqual(try sut.loadAll().map(\.id), [conversation.id])
    }
}
