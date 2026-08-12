//
//  AttachmentMigrationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AttachmentMigrationUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: AttachmentMigrationUseCase!
    private var mockAttachmentRepository: MockAttachmentRepository!
    private var testUserDefaults: UserDefaults!
    private var testUserDefaultsSuiteName: String!
    private var testDirectory: URL!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockAttachmentRepository = MockAttachmentRepository()

        // Isolated UserDefaults to avoid polluting real settings
        testUserDefaultsSuiteName = "AttachmentMigrationTests-\(UUID().uuidString)"
        testUserDefaults = try XCTUnwrap(
            UserDefaults(suiteName: testUserDefaultsSuiteName)
        )

        // Temp directory for test JSON files
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)

        sut = AttachmentMigrationUseCase(
            fileManager: .default,
            attachmentRepository: mockAttachmentRepository,
            userDefaults: testUserDefaults,
            baseDirectory: testDirectory
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testDirectory)
        testUserDefaults.removePersistentDomain(forName: testUserDefaultsSuiteName)
        sut = nil
        mockAttachmentRepository = nil
        testUserDefaults = nil
        testUserDefaultsSuiteName = nil
        testDirectory = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_skipsWhenAlreadyMigrated() {
        // Given
        testUserDefaults.set(true, forKey: "attachmentMigrationV1Done")

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
    }

    func test_execute_setsCompletionFlag() {
        // Given
        // No conversations to migrate (empty temp directory for Conversations)

        // When
        sut.execute()

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
    }

    func test_execute_migratesLegacyAttachmentData() throws {
        // Given — build a legacy conversation JSON with "data" key in attachment
        let conversationId = UUID()
        let attachmentId = UUID()
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // minimal JPEG header

        let legacyJSON: [String: Any] = [
            "id": conversationId.uuidString,
            "modelId": "gpt-4",
            "title": "Test",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "isPinned": false,
            "messages": [
                [
                    "id": UUID().uuidString,
                    "role": "user",
                    "content": "Look at this",
                    "createdAt": "2026-01-01T00:00:00Z",
                    "attachments": [
                        [
                            "id": attachmentId.uuidString,
                            "type": "image",
                            "fileName": "photo.jpg",
                            "data": imageData.base64EncodedString()
                        ]
                    ]
                ]
            ]
        ]

        let conversationsDir = testDirectory.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)
        let fileURL = conversationsDir.appendingPathComponent("\(conversationId.uuidString).json")
        let fileData = try JSONSerialization.data(withJSONObject: legacyJSON)
        try fileData.write(to: fileURL)

        mockAttachmentRepository.saveResult = .success("Attachments/\(conversationId)/\(attachmentId).jpg")

        // When
        sut.execute()

        // Then
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.count, 1)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.first?.data, imageData)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.first?.attachment.fileName, "photo.jpg")
        XCTAssertTrue(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
        try assertRecoveryContains(fileData)

        // The written JSON should no longer have "data" in attachments
        let updatedData = try Data(contentsOf: fileURL)
        let updatedJSON = try JSONSerialization.jsonObject(with: updatedData) as? [String: Any]
        let messages = updatedJSON?["messages"] as? [[String: Any]]
        let attachments = messages?.first?["attachments"] as? [[String: Any]]
        XCTAssertNil(attachments?.first?["data"], "Legacy 'data' key should be removed after migration")
        XCTAssertNotNil(attachments?.first?["fileRelativePath"], "New 'fileRelativePath' key should be present")
    }

    func test_execute_doesNotRepeatAfterCompletion() {
        // When — run twice
        sut.execute()
        sut.execute()

        // Then — repository called only from the first run (no conversations to migrate,
        // but the flag prevents the second run entirely)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.count, 0)
    }

    func test_execute_attachmentWriteFails_keepsMigrationRetryable() throws {
        // Given
        let conversationId = UUID()
        let legacyJSON: [String: Any] = [
            "id": conversationId.uuidString,
            "messages": [[
                "attachments": [[
                    "id": UUID().uuidString,
                    "type": "image",
                    "fileName": "photo.jpg",
                    "data": Data([0x01]).base64EncodedString()
                ]]
            ]]
        ]
        let conversationsURL = testDirectory.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: legacyJSON).write(
            to: conversationsURL.appendingPathComponent("\(conversationId.uuidString).json")
        )
        mockAttachmentRepository.saveResult = .failure(AttachmentRepositoryError.invalidPath)

        // When
        sut.execute()

        // Then
        XCTAssertFalse(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
    }

    func test_execute_conversationsPathIsFile_keepsMigrationRetryable() throws {
        // Given
        try Data("not a directory".utf8).write(
            to: testDirectory.appendingPathComponent("Conversations")
        )

        // When
        sut.execute()

        // Then
        XCTAssertFalse(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
    }

    func test_execute_sameDestinationWithDifferentBytes_doesNotWriteOrReplaceRawJSON() throws {
        // Given
        let conversationId = UUID()
        let attachmentId = UUID()
        let legacyJSON = legacyConversationJSON(
            conversationId: conversationId,
            attachments: [
                legacyAttachment(id: attachmentId, data: Data([0x01])),
                legacyAttachment(id: attachmentId, data: Data([0x02]))
            ]
        )
        let fileURL = try writeConversationFixture(legacyJSON, conversationId: conversationId)
        let rawData = try Data(contentsOf: fileURL)

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
        XCTAssertEqual(try Data(contentsOf: fileURL), rawData)
        XCTAssertFalse(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
        try assertRecoveryContains(rawData)
    }

    func test_execute_existingDestinationWithDifferentBytes_doesNotOverwriteFile() throws {
        // Given
        let conversationId = UUID()
        let attachmentId = UUID()
        let existingData = Data("existing".utf8)
        let incomingData = Data("incoming".utf8)
        let legacyJSON = legacyConversationJSON(
            conversationId: conversationId,
            attachments: [legacyAttachment(id: attachmentId, data: incomingData)]
        )
        let conversationURL = try writeConversationFixture(legacyJSON, conversationId: conversationId)
        let attachmentURL = testDirectory
            .appendingPathComponent("Attachments/\(conversationId.uuidString)", isDirectory: true)
            .appendingPathComponent("\(attachmentId.uuidString).jpg")
        try FileManager.default.createDirectory(
            at: attachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try existingData.write(to: attachmentURL)

        // When
        sut.execute()

        // Then
        XCTAssertEqual(try Data(contentsOf: attachmentURL), existingData)
        XCTAssertTrue(try JSONFixture(data: Data(contentsOf: conversationURL)).containsLegacyAttachmentData)
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
        XCTAssertFalse(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
    }

    func test_execute_finalAttachmentVerificationFails_restoresRawJSONAndRemainsRetryable() throws {
        // Given
        let conversationId = UUID()
        let firstId = UUID()
        let secondId = UUID()
        let firstData = Data([0x01])
        let secondData = Data([0x02])
        let legacyJSON = legacyConversationJSON(
            conversationId: conversationId,
            attachments: [
                legacyAttachment(id: firstId, data: firstData),
                legacyAttachment(id: secondId, data: secondData)
            ]
        )
        let fileURL = try writeConversationFixture(legacyJSON, conversationId: conversationId)
        let rawData = try Data(contentsOf: fileURL)
        mockAttachmentRepository.saveHandler = { attachment, conversationId in
            ConversationAttachmentPath.relativePath(for: attachment, conversationId: conversationId)
        }
        var loadCounts: [UUID: Int] = [:]
        mockAttachmentRepository.loadHandler = { attachment in
            loadCounts[attachment.id, default: 0] += 1
            if attachment.id == firstId, loadCounts[attachment.id] == 2 {
                return Data("changed".utf8)
            }
            return attachment.id == firstId ? firstData : secondData
        }

        // When
        sut.execute()

        // Then
        XCTAssertEqual(try Data(contentsOf: fileURL), rawData)
        XCTAssertFalse(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))
        try assertRecoveryContains(rawData)
    }
}

// MARK: - Helpers

private extension AttachmentMigrationUseCaseTests {
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

    func legacyAttachment(id: UUID, data: Data) -> [String: Any] {
        [
            "id": id.uuidString,
            "type": "image",
            "fileName": "photo.jpg",
            "data": data.base64EncodedString()
        ]
    }

    func legacyConversationJSON(
        conversationId: UUID,
        attachments: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": conversationId.uuidString,
            "modelId": "model",
            "title": "Migration fixture",
            "createdAt": "2026-08-11T10:00:00Z",
            "updatedAt": "2026-08-11T10:00:00Z",
            "isPinned": false,
            "messages": [[
                "id": UUID().uuidString,
                "role": "user",
                "content": "Attachments",
                "timestamp": "2026-08-11T10:00:00Z",
                "attachments": attachments
            ]]
        ]
    }

    func writeConversationFixture(_ json: [String: Any], conversationId: UUID) throws -> URL {
        let directory = testDirectory.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(conversationId.uuidString).json")
        try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]).write(to: url)
        return url
    }

    func assertRecoveryContains(_ data: Data) throws {
        let recoveryURL = testDirectory
            .appendingPathComponent("ConversationRecovery/Migrations/Attachments", isDirectory: true)
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: recoveryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(try recoveryFiles.contains { try Data(contentsOf: $0) == data })
    }
}
