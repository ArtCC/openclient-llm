//
//  CloudDataManagementPersistenceTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudDataManagementPersistenceTests: XCTestCase {
    // MARK: - Properties

    private var rootURL: URL!
    private var documentsURL: URL!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        documentsURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
        rootURL = nil
        documentsURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_loadConversationSnapshot_individualTombstoneIsNewer_filtersConversationFromInventory() async throws {
        // Given
        let conversation = Conversation(modelId: "model", updatedAt: Date(timeIntervalSince1970: 100))
        try seedConversation(conversation)
        let tombstone = ConversationTombstone(
            conversationId: conversation.id,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        try seed(tombstone, directory: "ConversationTombstones", id: conversation.id)

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        XCTAssertEqual(inventory.categories[.conversations], .available(.conversations([])))
    }

    func test_loadCloudInventory_emptyOrphanAttachmentFolder_reportsCorruptData() async throws {
        // Given
        let folder = documentsURL.appendingPathComponent("Attachments/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        XCTAssertEqual(inventory.categories[.conversations], .failed(.corruptData))
    }

    func test_loadCloudInventory_structuralCloudContentChanged_reportsCorruptData() async throws {
        // Given
        let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: directory.appendingPathComponent("not-a-uuid.json"))

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        XCTAssertEqual(inventory.categories[.promptTemplates], .failed(.corruptData))
    }

    func test_loadCloudInventory_externalTitles_sanitizesControlsWhitespaceAndLength() async throws {
        // Given
        let title = "  Visible\n\t\u{0000}" + String(repeating: "x", count: 200)
        let template = PromptTemplate(title: title, content: "Private")
        try seed(template, directory: "PromptTemplates", id: template.id)

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        guard case .available(.promptTemplates(let items)) = inventory.categories[.promptTemplates] else {
            return XCTFail("Expected template inventory")
        }
        XCTAssertEqual(items.first?.title.count, 100)
        XCTAssertFalse(items.first?.title.contains("\n") == true)
        XCTAssertFalse(
            items.first?.title.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) == true
        )
    }

    func test_deleteCloudData_parentPayloadAlreadyMissing_removesOrphanAttachmentFolder() async throws {
        // Given
        let folder = documentsURL.appendingPathComponent("Attachments/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("attachment".utf8).write(to: folder.appendingPathComponent("file.bin"))

        // When
        _ = try await makeManager().deleteCloudData(categories: [.conversations], marker: nil)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func test_deleteCloudData_completedCategory_repeatedCallKeepsNewerConversationAndAttachment() async throws {
        // Given
        let manager = makeManager()
        let first = try await manager.deleteCloudData(categories: [.conversations], marker: nil)
        let conversation = Conversation(
            modelId: "model",
            updatedAt: first.marker.deletedAt.addingTimeInterval(1)
        )
        try seedConversation(conversation)
        let folder = documentsURL.appendingPathComponent(
            "Attachments/\(conversation.id.uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: folder.appendingPathComponent("file.bin"))

        // When
        _ = try await manager.deleteCloudData(categories: [.conversations], marker: first.marker)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent(
                "Conversations/\(conversation.id.uuidString).json"
            ).path
        ))
    }

    func test_completeLocalPurgeCleanup_restartLoadsCompletedJournal() async throws {
        // Given
        let manager = makeManager()
        let result = try await manager.deleteCloudData(categories: [.memory], marker: nil)
        try await manager.completeLocalPurgeCleanup(category: .memory, marker: result.marker)

        // When
        let journal = try await makeManager().loadCloudPurgeJournal()

        // Then
        XCTAssertEqual(journal?.categoryStates[.memory], .completed)
        XCTAssertFalse(journal?.unfinishedCategories.contains(.memory) == true)
    }

    // MARK: - Private

    private func makeManager() -> CloudSyncManager {
        CloudSyncManager(containerProvider: FixedCloudContainerProvider(url: rootURL))
    }

    private func seedConversation(_ conversation: Conversation) throws {
        try seed(conversation, directory: "Conversations", id: conversation.id)
    }

    private func seed<Value: Encodable>(_ value: Value, directory: String, id: UUID) throws {
        let directoryURL = documentsURL.appendingPathComponent(directory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try SyncJSONCoding.makeEncoder().encode(value)
        try data.write(to: directoryURL.appendingPathComponent("\(id.uuidString).json"), options: .atomic)
    }
}
