//
//  ConversationRepositorySyncTests+Mutations.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension ConversationRepositorySyncTests {
    func test_setPinned_staleLocalConversation_mutatesReconciledCloudMessages() async throws {
        // Given
        let (local, cloud) = staleLocalAndNewerCloudConversation()
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true

        // When
        let updated = try await sut.setPinned(true, conversationId: local.id)

        // Then
        XCTAssertEqual(updated?.messages.count, 2)
        XCTAssertEqual(updated?.isPinned, true)
        XCTAssertEqual(cloudSyncManager.cloudConversations.first?.messages.count, 2)
    }

    func test_rename_staleLocalConversation_mutatesReconciledCloudMessages() async throws {
        // Given
        let (local, cloud) = staleLocalAndNewerCloudConversation()
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true

        // When
        let updated = try await sut.rename(local.id, title: "Renamed")

        // Then
        XCTAssertEqual(updated?.title, "Renamed")
        XCTAssertEqual(updated?.messages.count, 2)
        XCTAssertEqual(cloudSyncManager.cloudConversations.first?.messages.count, 2)
    }

    func test_updateTags_staleLocalConversation_mutatesReconciledCloudMessages() async throws {
        // Given
        let (local, cloud) = staleLocalAndNewerCloudConversation()
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true

        // When
        let updated = try await sut.updateTags(local.id, tags: [ConversationTag(name: "Work", color: .blue)])

        // Then
        XCTAssertEqual(updated?.tags.map(\.name), ["Work"])
        XCTAssertEqual(updated?.messages.count, 2)
        XCTAssertEqual(cloudSyncManager.cloudConversations.first?.messages.count, 2)
    }

    func test_rename_pendingCloudMetadata_persistsLocalMutationForLaterReconciliation() async throws {
        // Given
        let conversation = Conversation(title: "Original", modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.pendingConversationDownloads = true

        // When
        _ = try await sut.rename(conversation.id, title: "Renamed")

        // Then
        let localConversation = try await sut.loadLocal().first
        XCTAssertEqual(localConversation?.title, "Renamed")
        XCTAssertTrue(cloudSyncManager.syncedConversations.isEmpty)
    }

    func test_save_favouriteOnStaleLocalMessage_preservesNewerCloudMessages() async throws {
        // Given
        let (local, cloud) = staleLocalAndNewerCloudConversation()
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true
        var favouriteUpdate = local
        favouriteUpdate.messages[0].isFavourite = true
        favouriteUpdate.updatedAt = Date()

        // When
        try await sut.save(favouriteUpdate)

        // Then
        let cloudConversation = try XCTUnwrap(cloudSyncManager.cloudConversations.first)
        XCTAssertEqual(cloudConversation.messages.count, 2)
        XCTAssertTrue(cloudConversation.messages[0].isFavourite)
    }

    func test_save_modelPromptAndParametersOnStaleLocal_preservesNewerCloudMessages() async throws {
        // Given
        let (local, cloud) = staleLocalAndNewerCloudConversation()
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true
        var metadataUpdate = local
        metadataUpdate.modelId = "new-model"
        metadataUpdate.systemPrompt = "New prompt"
        metadataUpdate.modelParameters = ModelParameters(temperature: 0.2, maxTokens: 100)
        metadataUpdate.updatedAt = Date()

        // When
        try await sut.save(metadataUpdate)

        // Then
        let cloudConversation = try XCTUnwrap(cloudSyncManager.cloudConversations.first)
        XCTAssertEqual(cloudConversation.messages.count, 2)
        XCTAssertEqual(cloudConversation.modelId, "new-model")
        XCTAssertEqual(cloudConversation.systemPrompt, "New prompt")
        XCTAssertEqual(cloudConversation.modelParameters, metadataUpdate.modelParameters)
    }

    func test_delete_cloudApplyUnavailable_throwsWithoutChangingCanonicalLocalPayload() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let payloadURL = directory.appendingPathComponent(
            "Conversations/\(conversation.id.uuidString).json"
        )
        let canonicalData = try Data(contentsOf: payloadURL)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.syncError = CloudSyncError.containerIdentityChanged

        // When
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected unavailable cloud apply to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .unavailable)
        }

        // Then
        XCTAssertEqual(try Data(contentsOf: payloadURL), canonicalData)
        let pendingDeletionURL = directory.appendingPathComponent(
            "ConversationPendingDeletions/\(conversation.id.uuidString).json"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingDeletionURL.path))
        XCTAssertTrue(cloudSyncManager.cloudTombstones.isEmpty)
    }

    func test_delete_newerCloudRevision_createsBarrierAndDeletesBothCopies() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let local = Conversation(modelId: "model", updatedAt: timestamp)
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(local)
        let cloud = Conversation(
            id: local.id,
            title: "Newer cloud revision",
            modelId: "model",
            updatedAt: timestamp.addingTimeInterval(60)
        )
        cloudSyncManager.cloudConversations = [cloud]
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.delete(local.id)

        // Then
        let localConversations = try await sut.loadLocal()
        XCTAssertTrue(localConversations.isEmpty)
        XCTAssertTrue(cloudSyncManager.cloudConversations.isEmpty)
        let tombstone = try XCTUnwrap(cloudSyncManager.cloudTombstones.first)
        XCTAssertGreaterThan(tombstone.deletedAt, cloud.updatedAt)
    }

    func test_delete_snapshotPreflightUnavailable_throwsAndPreservesCanonicalLocalPayload() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.loadError = CloudSyncError.containerIdentityChanged

        // When
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected unavailable preflight to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .unavailable)
        }

        // Then
        let localIds = try await sut.loadLocal().map(\.id)
        let payloadURL = directory.appendingPathComponent(
            "Conversations/\(conversation.id.uuidString).json"
        )
        XCTAssertEqual(localIds, [conversation.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL.path))
        XCTAssertTrue(cloudSyncManager.cloudTombstones.isEmpty)
    }

    func test_deleteAll_newestCloudRevision_createsNewerPurgeBarrier() async throws {
        // Given
        let cloud = Conversation(
            modelId: "model",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        cloudSyncManager.cloudConversations = [cloud]

        // When
        try await sut.deleteAll()

        // Then
        XCTAssertTrue(cloudSyncManager.cloudConversations.isEmpty)
        let marker = try XCTUnwrap(cloudSyncManager.cloudDeleteAllMarker)
        XCTAssertGreaterThan(marker.deletedAt, cloud.updatedAt)
    }

    func test_synchronize_symlinkedAttachmentRoot_failsWithoutTouchingExternalData() async throws {
        // Given
        let outsideDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideDirectory) }
        let sentinelURL = outsideDirectory.appendingPathComponent("sentinel")
        let sentinelData = Data("sentinel".utf8)
        try sentinelData.write(to: sentinelURL)
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("Attachments", isDirectory: true),
            withDestinationURL: outsideDirectory
        )

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinelData)
    }

    func test_save_snapshotCapturedBeforeDelete_doesNotResurrectConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let initialConversations = try await sut.loadLocal()
        let base = try XCTUnwrap(initialConversations.first)
        try await sut.delete(conversation.id)
        var staleSave = base
        staleSave.messages.append(ChatMessage(role: .user, content: "Stale"))
        staleSave.updatedAt = Date()

        // When
        do {
            try await sut.save(staleSave, expectedBase: base)
            XCTFail("Expected stale save rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .staleConversationRevision)
            let localConversations = try await sut.loadLocal()
            XCTAssertTrue(localConversations.isEmpty)
        }
    }

    func test_save_snapshotBeforeLocalRename_preservesInterveningRename() async throws {
        // Given
        let conversation = Conversation(modelId: "model", messages: [ChatMessage(role: .user, content: "Hello")])
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let initialConversations = try await sut.loadLocal()
        let base = try XCTUnwrap(initialConversations.first)
        _ = try await sut.rename(conversation.id, title: "Renamed")
        var favouriteUpdate = base
        favouriteUpdate.messages[0].isFavourite = true
        favouriteUpdate.updatedAt = Date()

        // When
        try await sut.save(favouriteUpdate, expectedBase: base)

        // Then
        let savedConversations = try await sut.loadLocal()
        let saved = try XCTUnwrap(savedConversations.first)
        XCTAssertEqual(saved.title, "Renamed")
        XCTAssertTrue(saved.messages[0].isFavourite)
    }

    func test_save_baseOlderThanRemoteTombstone_rejectsStaleSave() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(conversation)
        let initialConversations = try await sut.loadLocal()
        let base = try XCTUnwrap(initialConversations.first)
        cloudSyncManager.cloudTombstones = [
            ConversationTombstone(
                conversationId: conversation.id,
                deletedAt: base.updatedAt.addingTimeInterval(1)
            )
        ]
        settingsManager.isCloudSyncEnabled = true
        var staleSave = base
        staleSave.systemPrompt = "Stale prompt"
        staleSave.updatedAt = Date()

        // When
        do {
            try await sut.save(staleSave, expectedBase: base)
            XCTFail("Expected remote deletion to reject stale save")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .staleConversationRevision)
        }
    }

    func test_save_newConversationWithExpectedBase_persistsFirstRevision() async throws {
        // Given
        settingsManager.isCloudSyncEnabled = false
        let base = Conversation(modelId: "model")
        var firstRevision = base
        firstRevision.messages = [ChatMessage(role: .user, content: "First message")]
        firstRevision.updatedAt = Date()

        // When
        try await sut.save(firstRevision, expectedBase: base)

        // Then
        let savedConversations = try await sut.loadLocal()
        let saved = try XCTUnwrap(savedConversations.first)
        XCTAssertEqual(saved.id, base.id)
        XCTAssertEqual(saved.messages.map(\.content), ["First message"])
    }

    func test_save_concurrentAppends_preservesBothDeviceHistories() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let firstMessage = ChatMessage(role: .user, content: "Initial", timestamp: timestamp)
        let base = Conversation(
            modelId: "model",
            messages: [firstMessage],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(base)
        let remoteMessage = ChatMessage(
            role: .assistant,
            content: "Remote append",
            timestamp: timestamp.addingTimeInterval(1)
        )
        var remote = base
        remote.messages.append(remoteMessage)
        remote.updatedAt = timestamp.addingTimeInterval(1)
        cloudSyncManager.cloudConversations = [remote]
        settingsManager.isCloudSyncEnabled = true
        let localMessage = ChatMessage(
            role: .user,
            content: "Local append",
            timestamp: timestamp.addingTimeInterval(2)
        )
        var local = base
        local.messages.append(localMessage)
        local.updatedAt = timestamp.addingTimeInterval(2)

        // When
        let firstSaved = try await sut.save(local, expectedBase: base)
        var followUp = local
        followUp.messages.append(ChatMessage(
            role: .assistant,
            content: "Follow-up",
            timestamp: timestamp.addingTimeInterval(3)
        ))
        followUp.updatedAt = timestamp.addingTimeInterval(3)
        let secondSaved = try await sut.save(followUp, expectedBase: local)

        // Then
        let cloud = try XCTUnwrap(cloudSyncManager.cloudConversations.first)
        let expected = Set(["Initial", "Remote append", "Local append", "Follow-up"])
        XCTAssertEqual(Set(firstSaved.messages.map(\.content)), expected.subtracting(["Follow-up"]))
        XCTAssertEqual(Set(secondSaved.messages.map(\.content)), expected)
        XCTAssertEqual(Set(cloud.messages.map(\.content)), expected)
    }

    func test_save_concurrentMessageEdits_rejectsWithoutOverwritingRemote() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let messageId = UUID()
        let baseMessage = ChatMessage(id: messageId, role: .user, content: "Original", timestamp: timestamp)
        let base = Conversation(modelId: "model", messages: [baseMessage], updatedAt: timestamp)
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(base)
        var remote = base
        remote.messages[0].content = "Remote edit"
        remote.updatedAt = timestamp.addingTimeInterval(1)
        cloudSyncManager.cloudConversations = [remote]
        settingsManager.isCloudSyncEnabled = true
        var local = base
        local.messages[0].content = "Local edit"
        local.updatedAt = timestamp.addingTimeInterval(2)

        // When
        do {
            try await sut.save(local, expectedBase: base)
            XCTFail("Expected concurrent edit rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .staleConversationRevision)
            XCTAssertEqual(cloudSyncManager.cloudConversations.first?.messages.first?.content, "Remote edit")
            let localConversations = try await sut.loadLocal()
            XCTAssertEqual(localConversations.first?.messages.first?.content, "Original")
        }
    }

    func test_synchronize_pendingOfflineSaveWithRemoteTombstone_doesNotResurrectConversation() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let base = Conversation(modelId: "model", updatedAt: timestamp)
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(base)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.cloudAvailable = false
        var offlineRevision = base
        offlineRevision.messages.append(ChatMessage(role: .user, content: "Offline change"))
        offlineRevision.updatedAt = timestamp.addingTimeInterval(2)
        try await sut.save(offlineRevision, expectedBase: base)
        cloudSyncManager.cloudAvailable = true
        cloudSyncManager.cloudTombstones = [
            ConversationTombstone(
                conversationId: base.id,
                deletedAt: timestamp.addingTimeInterval(1)
            )
        ]

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let localConversations = try await sut.loadLocal()
        XCTAssertTrue(localConversations.isEmpty)
        XCTAssertTrue(cloudSyncManager.cloudConversations.isEmpty)
        let recoveryURL = directory.appendingPathComponent("ConversationRecovery", isDirectory: true)
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: recoveryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(recoveryFiles.contains { $0.lastPathComponent.hasPrefix(base.id.uuidString) })
    }

    func test_synchronize_pendingOfflineAppendWithRemoteAppend_preservesBothChanges() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let base = Conversation(
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Initial", timestamp: timestamp)],
            updatedAt: timestamp
        )
        settingsManager.isCloudSyncEnabled = false
        try await sut.save(base)
        cloudSyncManager.cloudConversations = [base]
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.cloudAvailable = false
        var offline = base
        offline.messages.append(ChatMessage(
            role: .assistant,
            content: "Offline append",
            timestamp: timestamp.addingTimeInterval(2)
        ))
        offline.updatedAt = timestamp.addingTimeInterval(2)
        try await sut.save(offline, expectedBase: base)
        var remote = base
        remote.messages.append(ChatMessage(
            role: .assistant,
            content: "Remote append",
            timestamp: timestamp.addingTimeInterval(1)
        ))
        remote.updatedAt = timestamp.addingTimeInterval(1)
        cloudSyncManager.cloudConversations = [remote]
        cloudSyncManager.cloudAvailable = true

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let cloud = try XCTUnwrap(cloudSyncManager.cloudConversations.first)
        XCTAssertEqual(Set(cloud.messages.map(\.content)), Set(["Initial", "Offline append", "Remote append"]))
    }

}
