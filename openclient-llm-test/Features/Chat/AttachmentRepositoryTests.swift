//
//  AttachmentRepositoryTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AttachmentRepositoryTests: XCTestCase {
    // MARK: - Properties

    private var rootURL: URL!
    private var outsideURL: URL!
    private var sut: AttachmentRepository!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("sentinel".utf8).write(to: outsideURL)
        sut = AttachmentRepository(baseURL: rootURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
        try? FileManager.default.removeItem(at: outsideURL)
        sut = nil
        rootURL = nil
        outsideURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_load_pathTraversal_throwsWithoutReadingExternalFile() throws {
        // Given
        let attachment = makeAttachment(path: "Attachments/\(UUID().uuidString)/../sentinel")

        // When / Then
        XCTAssertThrowsError(try sut.load(attachment: attachment))
        XCTAssertEqual(try Data(contentsOf: outsideURL), Data("sentinel".utf8))
    }

    func test_delete_percentEncodedTraversal_throwsWithoutDeletingExternalFile() throws {
        // Given
        let attachment = makeAttachment(path: "Attachments/\(UUID().uuidString)/%2E%2E")

        // When / Then
        XCTAssertThrowsError(try sut.delete(attachment: attachment))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func test_attachmentPath_iCloudPlaceholderShapedFileName_throwsInvalidPath() throws {
        // Given
        let attachment = makeAttachment(path: "Attachments/\(UUID().uuidString)/.image.png.icloud")

        // When / Then
        XCTAssertThrowsError(try ConversationAttachmentPath.key(for: attachment)) { error in
            XCTAssertEqual(error as? CloudSyncError, .invalidAttachmentPath)
        }
    }

    func test_load_symlinkEscape_throwsWithoutReadingExternalFile() throws {
        // Given
        let conversationId = UUID()
        let relativePath = "Attachments/\(conversationId.uuidString)/image.png"
        let symlinkURL = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: symlinkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)
        let attachment = makeAttachment(path: relativePath)

        // When / Then
        XCTAssertThrowsError(try sut.load(attachment: attachment))
        XCTAssertEqual(try Data(contentsOf: outsideURL), Data("sentinel".utf8))
    }

    func test_save_validAttachment_writesInsideConversationFolder() throws {
        // Given
        let conversationId = UUID()
        let attachment = makeAttachment(path: "")
        let bytes = Data([0x01, 0x02])

        // When
        let relativePath = try sut.save(data: bytes, for: attachment, conversationId: conversationId)

        // Then
        XCTAssertTrue(relativePath.contains(conversationId.uuidString))
        XCTAssertEqual(try Data(contentsOf: rootURL.appendingPathComponent(relativePath)), bytes)
    }

    func test_save_symlinkedAttachmentRoot_throwsWithoutWritingOutsideRoot() throws {
        // Given
        let outsideDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideDirectory) }
        let attachmentRoot = rootURL.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: attachmentRoot, withDestinationURL: outsideDirectory)
        let attachment = makeAttachment(path: "")

        // When / Then
        XCTAssertThrowsError(try sut.save(data: Data([0x01]), for: attachment, conversationId: UUID()))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outsideDirectory.path).isEmpty)
    }

    func test_deleteAll_symlinkedConversationFolder_throwsWithoutDeletingOutsideFolder() throws {
        // Given
        let outsideDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideDirectory) }
        let sentinelURL = outsideDirectory.appendingPathComponent("sentinel")
        try Data("sentinel".utf8).write(to: sentinelURL)
        let conversationId = UUID()
        let attachmentRoot = rootURL.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: attachmentRoot.appendingPathComponent(conversationId.uuidString),
            withDestinationURL: outsideDirectory
        )

        // When / Then
        XCTAssertThrowsError(try sut.deleteAll(forConversationId: conversationId))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinelURL.path))
    }
}

// MARK: - Private

private extension AttachmentRepositoryTests {
    func makeAttachment(path: String) -> ChatMessage.Attachment {
        ChatMessage.Attachment(
            type: .image,
            fileName: "image.png",
            mimeType: "image/png",
            fileRelativePath: path
        )
    }
}
