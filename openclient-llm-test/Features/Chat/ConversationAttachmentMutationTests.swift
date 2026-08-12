//
//  ConversationAttachmentMutationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationAttachmentMutationTests: XCTestCase {
    func test_save_syncDisabled_transientAttachment_materializesWithConversation() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = false
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
        let bytes = Data("attachment".utf8)
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: "",
            transientData: bytes
        )
        let conversation = Conversation(
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Image", attachments: [attachment])]
        )

        // When
        let saved = try await repository.save(conversation)

        // Then
        let persistedAttachment = try XCTUnwrap(saved.messages.first?.attachments.first)
        XCTAssertNil(persistedAttachment.transientData)
        XCTAssertTrue(persistedAttachment.fileRelativePath.contains(conversation.id.uuidString))
        XCTAssertEqual(
            try Data(contentsOf: documentsURL.appendingPathComponent(persistedAttachment.fileRelativePath)),
            bytes
        )
    }

    func test_save_missingAttachmentBytes_doesNotPersistConversation() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = false
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
        let conversationId = UUID()
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "missing.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/\(conversationId.uuidString)/missing.png"
        )
        let conversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Image", attachments: [attachment])]
        )

        // When
        do {
            _ = try await repository.save(conversation)
            XCTFail("Expected missing attachment error")
        } catch {
            // Then
            let conversationURL = documentsURL
                .appendingPathComponent("Conversations", isDirectory: true)
                .appendingPathComponent("\(conversationId.uuidString).json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: conversationURL.path))
        }
    }

    func test_save_syncDisabled_removingAttachment_cleansBytesAndKeepsRecoveryCopy() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = false
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
        let conversationId = UUID()
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/\(conversationId.uuidString)/image.png"
        )
        let base = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Image", attachments: [attachment])]
        )
        let bytes = Data("attachment".utf8)
        let attachmentURL = documentsURL.appendingPathComponent(attachment.fileRelativePath)
        try FileManager.default.createDirectory(
            at: attachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: attachmentURL)
        try await repository.save(base)
        var updated = base
        updated.messages[0].attachments = []
        updated.updatedAt = Date()

        // When
        try await repository.save(updated, expectedBase: base)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentURL.path))
        let recoveryURL = documentsURL
            .appendingPathComponent("ConversationRecovery/Attachments", isDirectory: true)
            .appendingPathComponent(conversationId.uuidString, isDirectory: true)
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: recoveryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(try recoveryFiles.contains { try Data(contentsOf: $0) == bytes })
    }

    func test_setPinned_legacyInlineAttachment_materializesBytesTransactionally() async throws {
        // Given
        let fixture = try makeLegacyAttachmentFixture(cloudSyncEnabled: false)

        // When
        let updated = try await fixture.repository.setPinned(true, conversationId: fixture.conversationId)

        // Then
        let attachment = try XCTUnwrap(updated?.messages.first?.attachments.first)
        XCTAssertTrue(try XCTUnwrap(updated?.isPinned))
        XCTAssertNil(attachment.transientData)
        XCTAssertEqual(try Data(contentsOf: documentsURL(fixture, path: attachment.fileRelativePath)), fixture.bytes)
        XCTAssertFalse(try conversationJSON(fixture).containsLegacyAttachmentData)
    }

    func test_rename_cloudUnavailableLegacyAttachment_materializesPendingMutation() async throws {
        // Given
        let fixture = try makeLegacyAttachmentFixture(cloudSyncEnabled: true, cloudAvailable: false)

        // When
        let updated = try await fixture.repository.rename(fixture.conversationId, title: "Renamed")

        // Then
        let attachment = try XCTUnwrap(updated?.messages.first?.attachments.first)
        XCTAssertEqual(updated?.title, "Renamed")
        XCTAssertEqual(try Data(contentsOf: documentsURL(fixture, path: attachment.fileRelativePath)), fixture.bytes)
        let pendingURL = fixture.documentsURL
            .appendingPathComponent("ConversationPendingMutations", isDirectory: true)
            .appendingPathComponent("\(fixture.conversationId.uuidString).json")
        let pendingData = try Data(contentsOf: pendingURL)
        XCTAssertFalse(try JSONFixture(data: pendingData).containsLegacyAttachmentData)
    }

    func test_updateTags_legacyInlineAttachment_materializesBytes() async throws {
        // Given
        let fixture = try makeLegacyAttachmentFixture(cloudSyncEnabled: false)
        let tags = [ConversationTag(name: "Legacy", color: .blue)]

        // When
        let updated = try await fixture.repository.updateTags(fixture.conversationId, tags: tags)

        // Then
        let attachment = try XCTUnwrap(updated?.messages.first?.attachments.first)
        XCTAssertEqual(updated?.tags, tags)
        XCTAssertEqual(try Data(contentsOf: documentsURL(fixture, path: attachment.fileRelativePath)), fixture.bytes)
        XCTAssertFalse(try conversationJSON(fixture).containsLegacyAttachmentData)
    }
}

// MARK: - Private

private extension ConversationAttachmentMutationTests {
    struct LegacyFixture {
        let repository: ConversationRepository
        let documentsURL: URL
        let conversationId: UUID
        let bytes: Data
    }

    struct JSONFixture {
        let data: Data

        var containsLegacyAttachmentData: Bool {
            get throws {
                let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                let messages = try XCTUnwrap(root["messages"] as? [[String: Any]])
                let attachments = try XCTUnwrap(messages.first?["attachments"] as? [[String: Any]])
                return attachments.first?["data"] != nil
            }
        }
    }

    func makeLegacyAttachmentFixture(
        cloudSyncEnabled: Bool,
        cloudAvailable: Bool = true
    ) throws -> LegacyFixture {
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: documentsURL.appendingPathComponent("Conversations", isDirectory: true),
            withIntermediateDirectories: true
        )
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = cloudSyncEnabled
        let cloudSyncManager = MockCloudSyncManager()
        cloudSyncManager.cloudAvailable = cloudAvailable
        let repository = ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            attachmentRepository: AttachmentRepository(baseURL: documentsURL),
            baseDirectory: documentsURL
        )
        let conversationId = UUID()
        let bytes = Data("legacy attachment".utf8)
        let attachmentId = UUID()
        let data = try legacyConversationData(
            conversationId: conversationId,
            attachmentId: attachmentId,
            bytes: bytes
        )
        try data.write(
            to: documentsURL
                .appendingPathComponent("Conversations", isDirectory: true)
                .appendingPathComponent("\(conversationId.uuidString).json")
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: documentsURL) }
        return LegacyFixture(
            repository: repository,
            documentsURL: documentsURL,
            conversationId: conversationId,
            bytes: bytes
        )
    }

    func legacyConversationData(conversationId: UUID, attachmentId: UUID, bytes: Data) throws -> Data {
        let json: [String: Any] = [
            "id": conversationId.uuidString,
            "modelId": "model",
            "title": "Original",
            "createdAt": "2026-08-11T10:00:00Z",
            "updatedAt": "2026-08-11T10:00:00Z",
            "isPinned": false,
            "messages": [[
                "id": UUID().uuidString,
                "role": "user",
                "content": "Image",
                "timestamp": "2026-08-11T10:00:00Z",
                "attachments": [[
                    "id": attachmentId.uuidString,
                    "type": "image",
                    "fileName": "image.png",
                    "data": bytes.base64EncodedString()
                ]]
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    func conversationJSON(_ fixture: LegacyFixture) throws -> JSONFixture {
        let url = fixture.documentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(fixture.conversationId.uuidString).json")
        return JSONFixture(data: try Data(contentsOf: url))
    }

    func documentsURL(_ fixture: LegacyFixture, path: String) -> URL {
        fixture.documentsURL.appendingPathComponent(path)
    }
}
