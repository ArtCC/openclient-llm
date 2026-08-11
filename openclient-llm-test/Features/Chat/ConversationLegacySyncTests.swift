//
//  ConversationLegacySyncTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationLegacySyncTests: XCTestCase {
    // MARK: - Properties

    private var rootURL: URL!
    private var cloudContainerURL: URL!
    private var localDocumentsURL: URL!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cloudContainerURL = rootURL.appendingPathComponent("Cloud", isDirectory: true)
        localDocumentsURL = rootURL.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudContainerURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: localDocumentsURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
        rootURL = nil
        cloudContainerURL = nil
        localDocumentsURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_synchronize_cloudLegacyInlineAttachment_materializesAndPreservesExactBytes() async throws {
        // Given
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let conversation = legacyConversation()
        let legacyData = try legacyData(for: conversation, attachmentData: bytes)
        try writeCloudConversationData(legacyData, id: conversation.id)
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let localConversations = try await repository.loadLocal()
        let localConversation = try XCTUnwrap(localConversations.first)
        let attachment = try XCTUnwrap(localConversation.messages.first?.attachments.first)
        XCTAssertFalse(attachment.fileRelativePath.isEmpty)
        XCTAssertEqual(
            try Data(contentsOf: localDocumentsURL.appendingPathComponent(attachment.fileRelativePath)),
            bytes
        )
        let recoveryFiles = try recoveryData()
        XCTAssertTrue(recoveryFiles.contains(legacyData))
        let rewrittenData = try Data(contentsOf: cloudConversationURL(for: conversation.id))
        let rewrittenObject = try XCTUnwrap(JSONSerialization.jsonObject(with: rewrittenData) as? [String: Any])
        let messages = try XCTUnwrap(rewrittenObject["messages"] as? [[String: Any]])
        let attachments = try XCTUnwrap(messages.first?["attachments"] as? [[String: Any]])
        XCTAssertNil(attachments.first?["data"])
    }

    func test_synchronize_pendingAttachmentWithNewerTombstone_deletesParentWithoutDownload() async throws {
        // Given
        let conversation = conversationWithAttachment(updatedAt: .distantPast)
        try writeCloudConversationData(SyncJSONCoding.makeEncoder().encode(conversation), id: conversation.id)
        let attachment = try XCTUnwrap(conversation.messages.first?.attachments.first)
        let attachmentURL = cloudDocumentsURL.appendingPathComponent(attachment.fileRelativePath)
        try FileManager.default.createDirectory(
            at: attachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let placeholderURL = attachmentURL.deletingLastPathComponent()
            .appendingPathComponent(".\(attachmentURL.lastPathComponent).icloud")
        try Data().write(to: placeholderURL)
        let tombstone = ConversationTombstone(conversationId: conversation.id, deletedAt: Date())
        try SyncJSONCoding.makeEncoder().encode([tombstone]).write(
            to: localDocumentsURL.appendingPathComponent("ConversationTombstones.json"),
            options: .atomic
        )
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudConversationURL(for: conversation.id).path))
        let localConversations = try await repository.loadLocal()
        XCTAssertTrue(localConversations.isEmpty)
    }

    func test_branchWithAttachment_parentDeleted_secondDeviceKeepsForkBytes() async throws {
        // Given
        let bytes = Data([0x01, 0x02, 0x03])
        let parent = conversationWithAttachment(updatedAt: Date())
        try writeLocalConversation(parent, documentsURL: localDocumentsURL)
        let parentAttachment = try XCTUnwrap(parent.messages.first?.attachments.first)
        let parentAttachmentURL = localDocumentsURL.appendingPathComponent(parentAttachment.fileRelativePath)
        try FileManager.default.createDirectory(
            at: parentAttachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: parentAttachmentURL)
        let firstRepository = makeRepository()
        let initialSyncResult = await firstRepository.synchronize()
        XCTAssertEqual(initialSyncResult, .synchronized)
        let branchUseCase = BranchConversationUseCase(
            saveConversationUseCase: SaveConversationUseCase(repository: firstRepository),
            attachmentRepository: AttachmentRepository(baseURL: localDocumentsURL)
        )
        let sourceMessage = try XCTUnwrap(parent.messages.first)
        let fork = try await branchUseCase.execute(conversation: parent, fromMessageId: sourceMessage.id)
        try await firstRepository.delete(parent.id)
        let secondDeviceURL = rootURL.appendingPathComponent("SecondDevice", isDirectory: true)
        try FileManager.default.createDirectory(at: secondDeviceURL, withIntermediateDirectories: true)
        let secondRepository = makeRepository(at: secondDeviceURL)

        // When
        let result = await secondRepository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let secondConversations = try await secondRepository.loadLocal()
        let secondFork = try XCTUnwrap(secondConversations.first { $0.id == fork.id })
        let forkAttachment = try XCTUnwrap(secondFork.messages.first?.attachments.first)
        let downloadedBytes = try Data(
            contentsOf: secondDeviceURL.appendingPathComponent(forkAttachment.fileRelativePath)
        )
        XCTAssertEqual(downloadedBytes, bytes)
    }

    func test_synchronize_attachmentRemovedFromParent_cleansLocalAndCloudAfterRecovery() async throws {
        // Given
        let conversationId = UUID()
        let firstAttachment = attachment(fileName: "first.png", conversationId: conversationId)
        let secondAttachment = attachment(fileName: "second.png", conversationId: conversationId)
        let message = ChatMessage(
            role: .user,
            content: "Images",
            attachments: [firstAttachment, secondAttachment]
        )
        let conversation = Conversation(id: conversationId, modelId: "model", messages: [message])
        try writeLocalConversation(conversation, documentsURL: localDocumentsURL)
        try writeAttachment(Data("first".utf8), attachment: firstAttachment, documentsURL: localDocumentsURL)
        let removedBytes = Data("second".utf8)
        try writeAttachment(removedBytes, attachment: secondAttachment, documentsURL: localDocumentsURL)
        let repository = makeRepository()
        let initialResult = await repository.synchronize()
        XCTAssertEqual(initialResult, .synchronized)
        var updatedConversation = conversation
        updatedConversation.messages[0].attachments = [firstAttachment]
        updatedConversation.updatedAt = conversation.updatedAt.addingTimeInterval(1)

        // When
        try await repository.save(updatedConversation)

        // Then
        let localRemovedURL = localDocumentsURL.appendingPathComponent(secondAttachment.fileRelativePath)
        let cloudRemovedURL = cloudDocumentsURL.appendingPathComponent(secondAttachment.fileRelativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: localRemovedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudRemovedURL.path))
        let recoveryFiles = try attachmentRecoveryData(for: conversationId)
        XCTAssertTrue(recoveryFiles.contains(removedBytes))
    }

    func test_synchronize_losingCloudAttachmentPlaceholder_waitsBeforeConflictCleanup() async throws {
        // Given
        let conversationId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let cloudAttachment = attachment(fileName: "cloud.png", conversationId: conversationId)
        let cloudMessage = ChatMessage(role: .user, content: "Cloud", attachments: [cloudAttachment])
        let cloudConversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [cloudMessage],
            updatedAt: timestamp
        )
        let localConversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Local")],
            updatedAt: timestamp.addingTimeInterval(1)
        )
        try writeCloudConversationData(
            SyncJSONCoding.makeEncoder().encode(cloudConversation),
            id: conversationId
        )
        let cloudAttachmentURL = cloudDocumentsURL.appendingPathComponent(cloudAttachment.fileRelativePath)
        try FileManager.default.createDirectory(
            at: cloudAttachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let placeholderURL = cloudAttachmentURL.deletingLastPathComponent()
            .appendingPathComponent(".\(cloudAttachmentURL.lastPathComponent).icloud")
        try Data().write(to: placeholderURL)
        try writeLocalConversation(localConversation, documentsURL: localDocumentsURL)
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .pendingDownload)
        XCTAssertTrue(FileManager.default.fileExists(atPath: placeholderURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloudConversationURL(for: conversationId).path))
    }

    func test_synchronize_unpublishedLocalAttachment_doesNotCleanPendingBytes() async throws {
        // Given
        let conversationId = UUID()
        let pendingAttachment = attachment(fileName: "pending.png", conversationId: conversationId)
        let pendingURL = localDocumentsURL.appendingPathComponent(pendingAttachment.fileRelativePath)
        try FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let bytes = Data("pending".utf8)
        try bytes.write(to: pendingURL)
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertEqual(try Data(contentsOf: pendingURL), bytes)
    }

    func test_save_localLegacyInlineAttachment_materializesBeforeJSONRewrite() async throws {
        // Given
        let bytes = Data([0x01, 0x02, 0x03])
        let conversation = legacyConversation()
        let legacyData = try legacyData(for: conversation, attachmentData: bytes)
        try writeLocalConversationData(legacyData, id: conversation.id)
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = false
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: CloudSyncManager(
                containerProvider: FixedCloudContainerProvider(url: cloudContainerURL)
            ),
            attachmentRepository: AttachmentRepository(baseURL: localDocumentsURL),
            baseDirectory: localDocumentsURL
        )
        let localConversations = try await repository.loadLocal()
        let base = try XCTUnwrap(localConversations.first)
        var updated = base
        updated.title = "Updated"
        updated.updatedAt = Date()

        // When
        try await repository.save(updated, expectedBase: base)

        // Then
        let savedConversations = try await repository.loadLocal()
        let saved = try XCTUnwrap(savedConversations.first)
        let attachment = try XCTUnwrap(saved.messages.first?.attachments.first)
        XCTAssertFalse(attachment.fileRelativePath.isEmpty)
        XCTAssertEqual(
            try Data(contentsOf: localDocumentsURL.appendingPathComponent(attachment.fileRelativePath)),
            bytes
        )
    }

    func test_synchronize_legacyPendingFolder_rehomesAttachmentUnderParentConversation() async throws {
        // Given
        let conversationId = UUID()
        let pendingId = UUID()
        let attachmentId = UUID()
        let fileName = "\(attachmentId.uuidString).png"
        let oldPath = "Attachments/\(pendingId.uuidString)/\(fileName)"
        let attachment = ChatMessage.Attachment(
            id: attachmentId,
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: oldPath
        )
        let conversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Image", attachments: [attachment])]
        )
        try writeLocalConversation(conversation, documentsURL: localDocumentsURL)
        let bytes = Data("legacy-pending".utf8)
        let oldURL = localDocumentsURL.appendingPathComponent(oldPath)
        try FileManager.default.createDirectory(
            at: oldURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: oldURL)
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        let savedConversations = try await repository.loadLocal()
        let saved = try XCTUnwrap(savedConversations.first)
        let savedAttachment = try XCTUnwrap(saved.messages.first?.attachments.first)
        XCTAssertTrue(savedAttachment.fileRelativePath.contains(conversationId.uuidString))
        XCTAssertEqual(
            try Data(contentsOf: localDocumentsURL.appendingPathComponent(savedAttachment.fileRelativePath)),
            bytes
        )
    }

    func test_synchronize_remoteTombstone_removesLocalAttachmentWithoutRecoveryCopy() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let conversation = conversationWithAttachment(updatedAt: timestamp)
        try writeLocalConversation(conversation, documentsURL: localDocumentsURL)
        let attachment = try XCTUnwrap(conversation.messages.first?.attachments.first)
        try writeAttachment(Data("deleted".utf8), attachment: attachment, documentsURL: localDocumentsURL)
        let tombstone = ConversationTombstone(
            conversationId: conversation.id,
            deletedAt: timestamp.addingTimeInterval(1)
        )
        let tombstoneURL = cloudDocumentsURL
            .appendingPathComponent("ConversationTombstones", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        try FileManager.default.createDirectory(
            at: tombstoneURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try SyncJSONCoding.makeEncoder().encode(tombstone).write(to: tombstoneURL)
        let repository = makeRepository()

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: localDocumentsURL.appendingPathComponent(attachment.fileRelativePath).path
        ))
        let recoveryURL = localDocumentsURL
            .appendingPathComponent("ConversationRecovery/Attachments", isDirectory: true)
            .appendingPathComponent(conversation.id.uuidString, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recoveryURL.path))
    }
}

// MARK: - Private

private extension ConversationLegacySyncTests {
    var cloudDocumentsURL: URL {
        cloudContainerURL.appendingPathComponent("Documents", isDirectory: true)
    }

    func makeRepository(at documentsURL: URL? = nil) -> ConversationRepository {
        let documentsURL = documentsURL ?? localDocumentsURL
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        return ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: CloudSyncManager(
                containerProvider: FixedCloudContainerProvider(url: cloudContainerURL)
            ),
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
    }

    func legacyConversation() -> Conversation {
        let conversationId = UUID()
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "legacy.png",
            mimeType: "image/png",
            fileRelativePath: ""
        )
        return Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Legacy", attachments: [attachment])]
        )
    }

    func conversationWithAttachment(updatedAt: Date) -> Conversation {
        let conversationId = UUID()
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/\(conversationId.uuidString)/image.png"
        )
        return Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Image", attachments: [attachment])],
            updatedAt: updatedAt
        )
    }

    func attachment(fileName: String, conversationId: UUID) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            type: .image,
            fileName: fileName,
            mimeType: "image/png",
            fileRelativePath: "Attachments/\(conversationId.uuidString)/\(fileName)"
        )
    }

    func legacyData(for conversation: Conversation, attachmentData: Data) throws -> Data {
        let encoded = try SyncJSONCoding.makeEncoder().encode(conversation)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var messages = try XCTUnwrap(root["messages"] as? [[String: Any]])
        var attachments = try XCTUnwrap(messages.first?["attachments"] as? [[String: Any]])
        attachments[0].removeValue(forKey: "fileRelativePath")
        attachments[0].removeValue(forKey: "mimeType")
        attachments[0]["data"] = attachmentData.base64EncodedString()
        messages[0]["attachments"] = attachments
        root["messages"] = messages
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    func writeCloudConversationData(_ data: Data, id: UUID) throws {
        let url = cloudConversationURL(for: id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func writeLocalConversationData(_ data: Data, id: UUID) throws {
        let url = localDocumentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func writeLocalConversation(_ conversation: Conversation, documentsURL: URL) throws {
        let directory = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try SyncJSONCoding.makeEncoder().encode(conversation)
        let fileURL = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }

    func writeAttachment(
        _ data: Data,
        attachment: ChatMessage.Attachment,
        documentsURL: URL
    ) throws {
        let url = documentsURL.appendingPathComponent(attachment.fileRelativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func cloudConversationURL(for id: UUID) -> URL {
        cloudDocumentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    func recoveryData() throws -> [Data] {
        let directory = localDocumentsURL.appendingPathComponent("ConversationRecovery", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files.filter { $0.pathExtension == "json" }.map { try Data(contentsOf: $0) }
    }

    func attachmentRecoveryData(for conversationId: UUID) throws -> [Data] {
        let directory = localDocumentsURL
            .appendingPathComponent("ConversationRecovery/Attachments", isDirectory: true)
            .appendingPathComponent(conversationId.uuidString, isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files.map { try Data(contentsOf: $0) }
    }
}
