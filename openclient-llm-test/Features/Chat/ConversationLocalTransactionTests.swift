//
//  ConversationLocalTransactionTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationLocalTransactionTests: XCTestCase {
    func test_loadLocal_abandonedTransaction_restoresOriginalConversation() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let storage = ConversationStorage(
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: documentsURL
        )
        let conversation = Conversation(title: "Original", modelId: "model")
        try await storage.save(conversation)
        _ = try ConversationLocalTransaction(fileManager: .default, documentsURL: documentsURL)
        var mutated = conversation
        mutated.title = "Partial write"
        let conversationURL = documentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        try SyncJSONCoding.makeEncoder().encode(mutated).write(to: conversationURL, options: .atomic)

        // When
        let restored = try await storage.loadLocal()

        // Then
        XCTAssertEqual(restored.first?.title, "Original")
    }

    func test_recoverPendingTransaction_restoresMetadataPendingBaseAndAttachmentBytes() throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let conversationId = UUID()
        let attachmentKey = CloudAttachmentKey(conversationId: conversationId, fileName: "attachment.bin")
        let files: [String: Data] = [
            "ConversationTombstones.json": Data("tombstones".utf8),
            "ConversationDeleteAll.json": Data("marker".utf8),
            "ConversationPendingMutations/\(conversationId.uuidString).json": Data("pending".utf8),
            ConversationAttachmentPath.relativePath(for: attachmentKey): Data("attachment".utf8)
        ]
        for (path, data) in files {
            let url = documentsURL.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
        }
        _ = try ConversationLocalTransaction(
            fileManager: .default,
            documentsURL: documentsURL,
            attachmentKeys: [attachmentKey]
        )
        for path in files.keys {
            try FileManager.default.removeItem(at: documentsURL.appendingPathComponent(path))
        }

        // When
        try ConversationLocalTransaction.recoverPendingTransactions(
            fileManager: .default,
            documentsURL: documentsURL
        )

        // Then
        for (path, data) in files {
            XCTAssertEqual(try Data(contentsOf: documentsURL.appendingPathComponent(path)), data)
        }
    }

    func test_loadLocal_importConversationWrittenBeforeSaveError_rollsBackInterruptedBatch() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let storage = ConversationStorage(
            cloudSyncManager: MockCloudSyncManager(),
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: documentsURL
        )
        let existing = Conversation(title: "Existing", modelId: "model")
        try await storage.save(existing)
        _ = try ConversationLocalTransaction(fileManager: .default, documentsURL: documentsURL)
        let imported = Conversation(title: "Committed before error", modelId: "model")
        let importedURL = documentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(imported.id.uuidString).json")
        do {
            try SyncJSONCoding.makeEncoder().encode(imported).write(to: importedURL, options: .atomic)
            throw NSError(domain: "CommittedSave", code: 1)
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: importedURL.path))
        }

        // When
        let restored = try await storage.loadLocal()

        // Then
        XCTAssertEqual(restored.map(\.id), [existing.id])
        XCTAssertEqual(restored.first?.title, "Existing")
    }

    func test_commit_changedConversationJSON_rejectsCommitAndKeepsRecovery() throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let conversationsURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let originalData = try SyncJSONCoding.makeEncoder().encode(
            Conversation(title: "Original", modelId: "model")
        )
        let original = try SyncJSONCoding.makeDecoder().decode(Conversation.self, from: originalData)
        let url = conversationsURL.appendingPathComponent("\(original.id.uuidString).json")
        try originalData.write(to: url)
        let transaction = try ConversationLocalTransaction(fileManager: .default, documentsURL: documentsURL)
        var changed = original
        changed.title = "Changed"
        try SyncJSONCoding.makeEncoder().encode(changed).write(to: url, options: .atomic)

        // When / Then
        XCTAssertThrowsError(try transaction.commit(verifying: .init(conversations: [original.id: original])))
        try ConversationLocalTransaction.recoverPendingTransactions(
            fileManager: .default,
            documentsURL: documentsURL
        )
        let restored = try SyncJSONCoding.makeDecoder().decode(Conversation.self, from: Data(contentsOf: url))
        XCTAssertEqual(restored, original)
    }

    func test_commit_changedPendingBaseOrAttachmentBytes_rejectsCommit() throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let conversation = Conversation(modelId: "model")
        let pendingURL = documentsURL
            .appendingPathComponent("ConversationPendingMutations", isDirectory: true)
            .appendingPathComponent("\(conversation.id.uuidString).json")
        let key = CloudAttachmentKey(conversationId: conversation.id, fileName: "attachment.bin")
        let attachmentURL = documentsURL.appendingPathComponent(ConversationAttachmentPath.relativePath(for: key))
        try FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: attachmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try SyncJSONCoding.makeEncoder().encode(conversation).write(to: pendingURL)
        let originalBytes = Data("original".utf8)
        try originalBytes.write(to: attachmentURL)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let transaction = try ConversationLocalTransaction(
            fileManager: .default,
            documentsURL: documentsURL,
            attachmentKeys: [key]
        )
        try Data("changed".utf8).write(to: attachmentURL, options: .atomic)

        // When / Then
        XCTAssertThrowsError(try transaction.commit(verifying: .init(
            pendingMutationBases: [conversation.id: conversation],
            attachments: [key: originalBytes]
        )))
    }
}
