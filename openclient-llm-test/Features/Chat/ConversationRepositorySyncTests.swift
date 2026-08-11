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

    var sut: ConversationRepository!
    var settingsManager: MockSettingsManager!
    var cloudSyncManager: MockCloudSyncManager!
    var directory: URL!

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

    func test_synchronize_localConversation_uploadsWithoutDeletingIt() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertTrue(cloudSyncManager.syncedConversations.contains { $0.id == conversation.id })
        let localIds = try await sut.loadLocal().map(\.id)
        XCTAssertEqual(localIds, [conversation.id])
    }

    func test_synchronize_cloudConversation_restoresLocally() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        cloudSyncManager.cloudConversations = [conversation]

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let localIds = try await sut.loadLocal().map(\.id)
        XCTAssertEqual(localIds, [conversation.id])
    }

    func test_synchronize_withoutChanges_doesNotRewriteLocalConversation() async throws {
        // Given
        let conversation = Conversation(
            modelId: "model",
            updatedAt: Date(timeIntervalSince1970: 1_000_000)
        )
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        _ = await sut.synchronize()
        let fileURL = directory
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        let expectedModificationDate = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: expectedModificationDate], ofItemAtPath: fileURL.path)

        // When
        _ = await sut.synchronize()

        // Then
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        XCTAssertEqual(attributes[.modificationDate] as? Date, expectedModificationDate)
    }

    func test_synchronize_conflict_keepsMostRecentlyUpdatedConversation() async throws {
        // Given
        let id = UUID()
        let older = Conversation(id: id, title: "Older", modelId: "model", updatedAt: .distantPast)
        let newer = Conversation(id: id, title: "Newer", modelId: "model", updatedAt: Date())
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(older)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.cloudConversations = [newer]

        // When
        _ = await sut.synchronize()

        // Then
        let localConversation = try await sut.loadLocal().first
        XCTAssertEqual(localConversation?.title, "Newer")
    }

    func test_delete_tombstoneOlderThanRemoteConversation_preservesNewerVersion() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        cloudSyncManager.cloudConversations = [
            Conversation(id: conversation.id, modelId: "model", updatedAt: Date().addingTimeInterval(60))
        ]

        // When
        try await sut.delete(conversation.id)
        settingsManager.isCloudSyncEnabled = true
        _ = await sut.synchronize()

        // Then
        let local = try await sut.loadLocal()
        XCTAssertEqual(local.map(\.id), [conversation.id])
        XCTAssertFalse(cloudSyncManager.deletedIds.contains(conversation.id))
    }

    func test_delete_tombstoneNewerThanRemoteConversation_preventsRestoration() async throws {
        // Given
        let conversation = Conversation(modelId: "model", updatedAt: .distantPast)
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        cloudSyncManager.cloudConversations = [conversation]

        // When
        try await sut.delete(conversation.id)
        settingsManager.isCloudSyncEnabled = true
        _ = await sut.synchronize()

        // Then
        let local = try await sut.loadLocal()
        XCTAssertTrue(local.isEmpty)
        XCTAssertTrue(cloudSyncManager.deletedIds.contains(conversation.id))
    }

    func test_synchronize_pendingPlaceholder_preservesLocalConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.pendingConversationDownloads = true

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .pendingDownload)
        let localIds = try await sut.loadLocal().map(\.id)
        XCTAssertEqual(localIds, [conversation.id])
    }

    func test_deleteAll_syncDisabled_doesNotDeleteCloudConversationsLater() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        cloudSyncManager.cloudConversations = [conversation]

        // When
        try await sut.deleteAll()
        settingsManager.isCloudSyncEnabled = true
        _ = await sut.synchronize()

        // Then
        let localIds = try await sut.loadLocal().map(\.id)
        XCTAssertEqual(localIds, [conversation.id])
    }

    func test_deleteAll_syncEnabled_newerConversationSurvivesMarker() async throws {
        // Given
        let oldConversation = Conversation(modelId: "model", updatedAt: .distantPast)
        cloudSyncManager.cloudConversations = [oldConversation]

        // When
        try await sut.deleteAll()
        let newConversation = Conversation(modelId: "model", updatedAt: Date().addingTimeInterval(1))
        try await sut.save(newConversation)

        // Then
        let localIds = try await sut.loadLocal().map(\.id)
        XCTAssertEqual(localIds, [newConversation.id])
        XCTAssertTrue(cloudSyncManager.cloudConversations.contains { $0.id == newConversation.id })
    }

    func test_synchronize_corruptLocalConversation_failsAndPreservesOriginalBytes() async throws {
        // Given
        let corruptData = Data("not-json".utf8)
        let conversationsDirectory = directory.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsDirectory, withIntermediateDirectories: true)
        let corruptURL = conversationsDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try corruptData.write(to: corruptURL)

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(try Data(contentsOf: corruptURL), corruptData)
    }

    func test_synchronize_identityChangesDuringApply_restoresExactLocalBytes() async throws {
        // Given
        let conversation = Conversation(title: "Local", modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let fileURL = directory
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        let originalData = try Data(contentsOf: fileURL)
        cloudSyncManager.cloudConversations = [
            Conversation(
                id: conversation.id,
                title: "Cloud",
                modelId: "model",
                updatedAt: conversation.updatedAt.addingTimeInterval(1)
            )
        ]
        cloudSyncManager.syncError = CloudSyncError.containerIdentityChanged
        settingsManager.isCloudSyncEnabled = true

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(try Data(contentsOf: fileURL), originalData)
    }

    func test_delete_repeatedWithoutNewRecord_keepsTombstoneUnchanged() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        try await sut.save(conversation)
        try await sut.delete(conversation.id)
        let tombstonesURL = directory.appendingPathComponent("ConversationTombstones.json")
        let originalData = try Data(contentsOf: tombstonesURL)
        let originalCloudDate = try XCTUnwrap(cloudSyncManager.cloudTombstones.first?.deletedAt)

        // When
        try await sut.delete(conversation.id)

        // Then
        XCTAssertEqual(try Data(contentsOf: tombstonesURL), originalData)
        XCTAssertEqual(cloudSyncManager.cloudTombstones.first?.deletedAt, originalCloudDate)
    }

    func test_deleteAll_repeatedWithoutNewRecord_keepsMarkerUnchanged() async throws {
        // Given
        try await sut.save(Conversation(modelId: "model"))
        try await sut.deleteAll()
        let markerURL = directory.appendingPathComponent("ConversationDeleteAll.json")
        let originalData = try Data(contentsOf: markerURL)
        let originalCloudDate = try XCTUnwrap(cloudSyncManager.cloudDeleteAllMarker?.deletedAt)

        // When
        try await sut.deleteAll()

        // Then
        XCTAssertEqual(try Data(contentsOf: markerURL), originalData)
        XCTAssertEqual(cloudSyncManager.cloudDeleteAllMarker?.deletedAt, originalCloudDate)
    }

    func test_deleteAll_syncDisabled_clearsLocalDeletionMetadataAndRecovery() async throws {
        // Given
        settingsManager.isCloudSyncEnabled = false
        let conversation = Conversation(modelId: "model")
        try await sut.save(conversation)
        try await sut.delete(conversation.id)
        let recoveryURL = directory.appendingPathComponent("ConversationRecovery", isDirectory: true)
        try FileManager.default.createDirectory(at: recoveryURL, withIntermediateDirectories: true)
        try Data("recovery".utf8).write(to: recoveryURL.appendingPathComponent("recovery.json"))

        // When
        try await sut.deleteAll()

        // Then
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("ConversationTombstones.json").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("ConversationDeleteAll.json").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recoveryURL.path))
    }

    func test_deleteAll_syncDisabled_staleQueuedSaveCannotRecreateConversation() async throws {
        // Given
        settingsManager.isCloudSyncEnabled = false
        let conversation = Conversation(modelId: "model")
        try await sut.save(conversation)
        var staleSave = conversation
        staleSave.messages.append(ChatMessage(role: .user, content: "Stale"))
        try await sut.deleteAll()

        // When
        do {
            try await sut.save(staleSave, expectedBase: conversation)
            XCTFail("Expected reset fence to reject the stale save")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .staleConversationRevision)
            let local = try await sut.loadLocal()
            XCTAssertTrue(local.isEmpty)
        }
    }

    func test_delete_attachmentRemovalFails_rollsBackPayloadAndTombstone() async throws {
        // Given
        settingsManager.isCloudSyncEnabled = false
        let attachmentRepository = MockAttachmentRepository()
        attachmentRepository.deleteAllError = AttachmentRepositoryError.invalidPath
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            attachmentRepository: attachmentRepository,
            baseDirectory: directory
        )
        let conversation = Conversation(modelId: "model")
        try await repository.save(conversation)

        // When
        do {
            try await repository.delete(conversation.id)
            XCTFail("Expected local deletion failure")
        } catch {
            // Then
            let local = try await repository.loadLocal()
            XCTAssertEqual(local.map(\.id), [conversation.id])
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("ConversationTombstones.json").path
            ))
        }
    }

}
