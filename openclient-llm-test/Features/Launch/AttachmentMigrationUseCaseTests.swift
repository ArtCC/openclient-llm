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

        // Inject a custom sut that reads from our test directory
        sut = AttachmentMigrationUseCase(
            fileManager: .default,
            attachmentRepository: mockAttachmentRepository,
            userDefaults: testUserDefaults,
            baseDirectory: testDirectory
        )

        // When
        sut.execute()

        // Then
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.count, 1)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.first?.data, imageData)
        XCTAssertEqual(mockAttachmentRepository.savedAttachments.first?.attachment.fileName, "photo.jpg")
        XCTAssertTrue(testUserDefaults.bool(forKey: "attachmentMigrationV1Done"))

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
}

// MARK: - Helpers
// (No helpers needed — testDirectory is injected directly via baseDirectory parameter)
