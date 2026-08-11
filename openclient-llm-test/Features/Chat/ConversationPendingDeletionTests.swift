//
//  ConversationPendingDeletionTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationPendingDeletionTests: XCTestCase {
    // MARK: - Properties

    private var documentsURL: URL!
    private var settingsManager: MockSettingsManager!
    private var cloudSyncManager: MockCloudSyncManager!
    private var sut: ConversationRepository!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager = MockCloudSyncManager()
        sut = makeRepository()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: documentsURL)
        sut = nil
        cloudSyncManager = nil
        settingsManager = nil
        documentsURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_delete_metadataPending_throwsWithoutChangingCanonicalLocalPayload() async throws {
        // Given
        let conversation = try await saveLocalConversation()
        cloudSyncManager.pendingConversationDownloads = true

        // When
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected pending metadata to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .pendingDownload)
        }

        // Then
        let conversations = try await sut.loadLocal()
        XCTAssertEqual(conversations.map(\.id), [conversation.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL(for: conversation.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL(for: conversation.id).path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("ConversationTombstones.json").path
        ))
        XCTAssertTrue(cloudSyncManager.cloudTombstones.isEmpty)
    }

    func test_delete_unavailableAfterRestart_keepsCanonicalPayloadVisible() async throws {
        // Given
        let conversation = try await saveLocalConversation()
        cloudSyncManager.cloudAvailable = false
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected unavailable cloud to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .unavailable)
        }
        let restartedRepository = makeRepository()

        // When
        let conversations = try await restartedRepository.loadLocal()

        // Then
        XCTAssertEqual(conversations.map(\.id), [conversation.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL(for: conversation.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL(for: conversation.id).path))
    }

    func test_delete_unavailableThenSynchronize_reconcilesWithoutDeletionIntent() async throws {
        // Given
        let localDate = Date(timeIntervalSince1970: 1_700_000_000)
        let conversation = try await saveLocalConversation(updatedAt: localDate)
        cloudSyncManager.cloudAvailable = false
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected unavailable cloud to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .unavailable)
        }
        let newerCloud = Conversation(
            id: conversation.id,
            title: "Newer cloud revision",
            modelId: "model",
            updatedAt: localDate.addingTimeInterval(60)
        )
        cloudSyncManager.cloudConversations = [newerCloud]
        cloudSyncManager.cloudAvailable = true

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertEqual(cloudSyncManager.cloudConversations.map(\.title), ["Newer cloud revision"])
        XCTAssertTrue(cloudSyncManager.cloudTombstones.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL(for: conversation.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL(for: conversation.id).path))
    }

    func test_delete_metadataPending_preservesAttachmentAndNoDeletionIntent() async throws {
        // Given
        let bytes = Data("attachment".utf8)
        let conversation = try await saveLocalConversation(attachmentData: bytes)
        let key = try attachmentKey(for: conversation)
        cloudSyncManager.cloudConversations = [conversation]
        cloudSyncManager.cloudAttachmentData = [key: bytes]
        cloudSyncManager.pendingConversationDownloads = true
        do {
            try await sut.delete(conversation.id)
            XCTFail("Expected pending metadata to reject the delete")
        } catch {
            XCTAssertEqual(error as? ConversationSyncOperationError, .pendingDownload)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL(for: conversation).path))
        cloudSyncManager.pendingConversationDownloads = false

        // When
        let result = await sut.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL(for: conversation.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL(for: conversation).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL(for: conversation.id).path))
        XCTAssertTrue(cloudSyncManager.cloudTombstones.isEmpty)
    }

    func test_save_revisionNewerThanFinalizedTombstone_recreatesConversation() async throws {
        // Given
        let conversation = try await saveLocalConversation()
        cloudSyncManager.cloudConversations = [conversation]
        try await sut.delete(conversation.id)
        let tombstone = try XCTUnwrap(cloudSyncManager.cloudTombstones.first)
        let recreated = Conversation(
            id: conversation.id,
            title: "Recreated",
            modelId: "model",
            updatedAt: tombstone.deletedAt.addingTimeInterval(1)
        )

        // When
        try await sut.save(recreated)

        // Then
        let localTitles = try await sut.loadLocal().map(\.title)
        XCTAssertEqual(localTitles, ["Recreated"])
        XCTAssertEqual(cloudSyncManager.cloudConversations.map(\.title), ["Recreated"])
    }

    func test_purgeLocalData_afterRestart_removesStalePendingMutationAndPayload() async throws {
        // Given
        let base = try await saveLocalConversation()
        let storage = makeStorage()
        try await storage.savePendingMutationBase(base)
        let restartedRepository = makeRepository()
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: base.updatedAt.addingTimeInterval(1))

        // When
        try await restartedRepository.purgeLocalData(through: marker)

        // Then
        let conversations = try await restartedRepository.loadLocal()
        XCTAssertTrue(conversations.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingMutationURL(for: base.id).path))
    }

    func test_purgeLocalData_cloudOnlyPendingDeletion_removesStaleMetadataWithoutCloudMutation() async throws {
        // Given
        let cloudConversation = Conversation(
            modelId: "model",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        cloudSyncManager.cloudConversations = [cloudConversation]
        let storage = makeStorage()
        try await storage.savePendingDeletion(conversationId: cloudConversation.id)
        let marker = CloudPurgeMarker(
            id: UUID(),
            deletedAt: cloudConversation.updatedAt.addingTimeInterval(1)
        )

        // When
        try await sut.purgeLocalData(through: marker)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL(for: cloudConversation.id).path))
        XCTAssertEqual(cloudSyncManager.cloudConversations.map(\.id), [cloudConversation.id])
    }

    func test_purgeLocalData_alreadyAbsentPayload_removesStalePendingMutationMetadata() async throws {
        // Given
        let base = Conversation(
            modelId: "model",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let storage = makeStorage()
        try await storage.savePendingMutationBase(base)
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: base.updatedAt.addingTimeInterval(1))

        // When
        try await sut.purgeLocalData(through: marker)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: payloadURL(for: base.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingMutationURL(for: base.id).path))
    }

    func test_purgeLocalData_postMarkerPendingWork_preservesPayloadAndMetadata() async throws {
        // Given
        let markerDate = Date(timeIntervalSince1970: 1_700_000_000)
        let conversation = try await saveLocalConversation(updatedAt: markerDate.addingTimeInterval(2))
        let storage = makeStorage()
        try await storage.savePendingMutationBase(conversation)
        try await storage.savePendingDeletion(conversationId: conversation.id)
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: markerDate)

        // When
        try await sut.purgeLocalData(through: marker)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: payloadURL(for: conversation.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingMutationURL(for: conversation.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL(for: conversation.id).path))
    }

    func test_purgeLocalData_postMarkerPendingBaseWithoutPayload_preservesPendingMetadata() async throws {
        // Given
        let markerDate = Date(timeIntervalSince1970: 1_700_000_000)
        let base = Conversation(modelId: "model", updatedAt: markerDate.addingTimeInterval(1))
        let storage = makeStorage()
        try await storage.savePendingMutationBase(base)
        try await storage.savePendingDeletion(conversationId: base.id)
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: markerDate)

        // When
        try await sut.purgeLocalData(through: marker)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: payloadURL(for: base.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingMutationURL(for: base.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL(for: base.id).path))
    }
}

// MARK: - Private

private extension ConversationPendingDeletionTests {
    func makeRepository() -> ConversationRepository {
        ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
    }

    func makeStorage() -> ConversationStorage {
        ConversationStorage(
            cloudSyncManager: cloudSyncManager,
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
    }

    func saveLocalConversation(
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        attachmentData: Data? = nil
    ) async throws -> Conversation {
        settingsManager.isCloudSyncEnabled = false
        let conversationId = UUID()
        let attachments: [ChatMessage.Attachment]
        if let attachmentData {
            let attachment = ChatMessage.Attachment(
                type: .pdf,
                fileName: "attachment.bin",
                mimeType: "application/octet-stream",
                fileRelativePath: "Attachments/\(conversationId.uuidString)/attachment.bin"
            )
            attachments = [attachment]
            let url = documentsURL.appendingPathComponent(attachment.fileRelativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try attachmentData.write(to: url)
        } else {
            attachments = []
        }
        let conversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Message", attachments: attachments)],
            updatedAt: updatedAt
        )
        try await sut.save(conversation)
        settingsManager.isCloudSyncEnabled = true
        return conversation
    }

    func payloadURL(for conversationId: UUID) -> URL {
        documentsURL.appendingPathComponent("Conversations/\(conversationId.uuidString).json")
    }

    func pendingURL(for conversationId: UUID) -> URL {
        documentsURL.appendingPathComponent("ConversationPendingDeletions/\(conversationId.uuidString).json")
    }

    func pendingMutationURL(for conversationId: UUID) -> URL {
        documentsURL.appendingPathComponent("ConversationPendingMutations/\(conversationId.uuidString).json")
    }

    func attachmentURL(for conversation: Conversation) -> URL {
        documentsURL.appendingPathComponent(conversation.messages[0].attachments[0].fileRelativePath)
    }

    func attachmentKey(for conversation: Conversation) throws -> CloudAttachmentKey {
        try XCTUnwrap(try ConversationAttachmentPath.key(
            for: try XCTUnwrap(conversation.messages.first?.attachments.first),
            conversationId: conversation.id
        ))
    }
}
