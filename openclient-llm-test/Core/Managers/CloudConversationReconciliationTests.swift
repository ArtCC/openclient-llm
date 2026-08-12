//
//  CloudConversationReconciliationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudConversationReconciliationTests: XCTestCase {
    // MARK: - Properties

    private var rootURL: URL!
    private var cloudContainerURL: URL!
    private var fileManager: ReconciliationFileManager!
    private var sut: CloudSyncManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cloudContainerURL = rootURL.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudContainerURL, withIntermediateDirectories: true)
        fileManager = ReconciliationFileManager()
        sut = CloudSyncManager(
            fileManager: fileManager,
            containerProvider: FixedCloudContainerProvider(url: cloudContainerURL)
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
        sut = nil
        fileManager = nil
        cloudContainerURL = nil
        rootURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_loadSnapshot_conversationsDirectoryPlaceholder_requestsDownloadAndThrowsPending() throws {
        try assertDirectoryPlaceholderIsPending(name: "Conversations")
    }

    func test_loadSnapshot_tombstonesDirectoryPlaceholder_requestsDownloadAndThrowsPending() throws {
        try assertDirectoryPlaceholderIsPending(name: "ConversationTombstones")
    }

    func test_loadSnapshot_attachmentsDirectoryPlaceholder_requestsDownloadAndThrowsPending() throws {
        try assertDirectoryPlaceholderIsPending(name: "Attachments")
    }

    func test_loadSnapshot_requiredAttachmentSubdirectoryPlaceholder_requestsDownloadAndThrowsPending() throws {
        // Given
        let conversationId = UUID()
        let attachment = ChatMessage.Attachment(
            type: .pdf,
            fileName: "document.pdf",
            mimeType: "application/pdf",
            fileRelativePath: "Attachments/\(conversationId.uuidString)/document.pdf"
        )
        let conversation = Conversation(
            id: conversationId,
            modelId: "model",
            messages: [ChatMessage(role: .user, content: "Document", attachments: [attachment])]
        )
        let conversationURL = cloudDocumentsURL
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent("\(conversationId.uuidString).json")
        try FileManager.default.createDirectory(
            at: conversationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try SyncJSONCoding.makeEncoder().encode(conversation).write(to: conversationURL)
        let attachmentsURL = cloudDocumentsURL.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        let placeholderURL = attachmentsURL.appendingPathComponent(".\(conversationId.uuidString).icloud")
        try Data().write(to: placeholderURL)

        // When
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }

        // Then
        XCTAssertEqual(fileManager.requestedDownloads, [placeholderURL])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: cloudDocumentsURL.appendingPathComponent("SyncManifest.json").path
        ))
    }

    func test_loadSnapshot_unreferencedAttachmentSubdirectoryPlaceholder_requestsDownloadWithoutBlocking() throws {
        // Given
        let attachmentsURL = cloudDocumentsURL.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        let placeholderURL = attachmentsURL.appendingPathComponent(".\(UUID().uuidString).icloud")
        try Data().write(to: placeholderURL)

        // When
        let snapshot = try sut.loadConversationSyncSnapshot()

        // Then
        XCTAssertTrue(snapshot.conversations.isEmpty)
        XCTAssertEqual(fileManager.requestedDownloads, [placeholderURL])
    }

    func test_loadSnapshot_duplicateLogicalConversationId_throwsAndPreservesBothFiles() throws {
        // Given
        let conversationId = UUID()
        let first = Conversation(id: conversationId, title: "First", modelId: "model")
        let second = Conversation(id: conversationId, title: "Second", modelId: "model")
        let firstData = try SyncJSONCoding.makeEncoder().encode(first)
        let secondData = try SyncJSONCoding.makeEncoder().encode(second)
        let firstURL = rootURL.appendingPathComponent("First/\(conversationId.uuidString).json")
        let secondURL = rootURL.appendingPathComponent("Second/\(conversationId.uuidString).json")
        try FileManager.default.createDirectory(
            at: firstURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: secondURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try firstData.write(to: firstURL)
        try secondData.write(to: secondURL)
        let conversationsURL = cloudDocumentsURL.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        fileManager.setContents([secondURL, firstURL], for: conversationsURL)

        // When
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .invalidConversationData)
        }

        // Then
        XCTAssertEqual(try Data(contentsOf: firstURL), firstData)
        XCTAssertEqual(try Data(contentsOf: secondURL), secondData)
    }
}

// MARK: - Private

private extension CloudConversationReconciliationTests {
    var cloudDocumentsURL: URL {
        cloudContainerURL.appendingPathComponent("Documents", isDirectory: true)
    }

    func assertDirectoryPlaceholderIsPending(name: String) throws {
        // Given
        try FileManager.default.createDirectory(at: cloudDocumentsURL, withIntermediateDirectories: true)
        let placeholderURL = cloudDocumentsURL.appendingPathComponent(".\(name).icloud")
        try Data().write(to: placeholderURL)

        // When
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }

        // Then
        XCTAssertEqual(fileManager.requestedDownloads, [placeholderURL])
        XCTAssertTrue(FileManager.default.fileExists(atPath: placeholderURL.path))
    }
}

// Safety: Mutable test observations and directory overrides are protected by `lock`.
nonisolated private final class ReconciliationFileManager: FileManager, @unchecked Sendable {
    private let lock = NSLock()
    private var contentsByPath: [String: [URL]] = [:]
    private var downloads: [URL] = []

    var requestedDownloads: [URL] {
        lock.withLock { downloads }
    }

    func setContents(_ contents: [URL], for directory: URL) {
        lock.withLock { contentsByPath[directory.path] = contents }
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if let contents = lock.withLock({ contentsByPath[url.path] }) {
            return contents
        }
        return try super.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: mask
        )
    }

    override func startDownloadingUbiquitousItem(at url: URL) throws {
        lock.withLock { downloads.append(url) }
    }
}
