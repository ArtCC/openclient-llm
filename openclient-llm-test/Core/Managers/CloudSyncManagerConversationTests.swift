//
//  CloudSyncManagerConversationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncManagerConversationTests: XCTestCase {
    // MARK: - Properties

    private var rootURL: URL!
    private var cloudContainerURL: URL!
    private var localDocumentsURL: URL!
    private var sut: CloudSyncManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cloudContainerURL = rootURL.appendingPathComponent("Cloud", isDirectory: true)
        localDocumentsURL = rootURL.appendingPathComponent("Local", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudContainerURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: localDocumentsURL, withIntermediateDirectories: true)
        sut = makeManager()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
        sut = nil
        rootURL = nil
        cloudContainerURL = nil
        localDocumentsURL = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_applySnapshot_legacyContainer_writesManifestAndConversation() throws {
        // Given
        let conversation = Conversation(modelId: "model")
        let snapshot = try sut.loadConversationSyncSnapshot()

        // When
        try sut.applyConversationSyncOutput(
            output(conversations: [conversation]),
            basedOn: snapshot
        )

        // Then
        let manifestData = try Data(contentsOf: cloudDocumentsURL.appendingPathComponent("SyncManifest.json"))
        XCTAssertEqual(try CloudSyncManifest.decode(manifestData), .current)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloudConversationURL(for: conversation.id).path))
    }

    func test_loadSnapshot_missingManifest_readsLegacyVersionOneData() throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let conversation = Conversation(modelId: "model", createdAt: timestamp, updatedAt: timestamp)
        try writeCloudConversation(conversation)

        // When
        let snapshot = try sut.loadConversationSyncSnapshot()

        // Then
        XCTAssertEqual(snapshot.conversations[conversation.id], conversation)
    }

    func test_loadSnapshot_unsupportedManifest_performsNoConversationWrite() throws {
        // Given
        try FileManager.default.createDirectory(at: cloudDocumentsURL, withIntermediateDirectories: true)
        let unsupported = CloudSyncManifest(
            format: CloudSyncManifest.expectedFormat,
            schemaVersion: 2,
            minimumReaderVersion: 2
        )
        try JSONEncoder().encode(unsupported).write(
            to: cloudDocumentsURL.appendingPathComponent("SyncManifest.json"),
            options: .atomic
        )

        // When
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncManifest.ValidationError, .unsupportedSchemaVersion(2))
        }

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudConversationsURL.path))
    }

    func test_save_unsupportedManifest_persistsMutationLocallyWithoutCloudWrite() async throws {
        // Given
        let base = Conversation(modelId: "model")
        try writeLocalConversation(base, to: localDocumentsURL)
        try FileManager.default.createDirectory(at: cloudDocumentsURL, withIntermediateDirectories: true)
        let unsupported = CloudSyncManifest(
            format: CloudSyncManifest.expectedFormat,
            schemaVersion: 2,
            minimumReaderVersion: 2
        )
        try JSONEncoder().encode(unsupported).write(
            to: cloudDocumentsURL.appendingPathComponent("SyncManifest.json"),
            options: .atomic
        )
        let repository = makeRepository(localDocuments: localDocumentsURL)
        var updated = base
        updated.messages.append(ChatMessage(role: .user, content: "Local change"))
        updated.updatedAt = Date()

        // When
        try await repository.save(updated, expectedBase: base)

        // Then
        let local = try await repository.loadLocal()
        XCTAssertEqual(local.first?.messages.map(\.content), ["Local change"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudConversationsURL.path))
    }

    func test_loadSnapshot_corruptCloudFile_throwsWithoutChangingBytes() throws {
        // Given
        let corruptData = Data("not-json".utf8)
        let conversationURL = cloudConversationURL(for: UUID())
        try FileManager.default.createDirectory(
            at: conversationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try corruptData.write(to: conversationURL)

        // When
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot())

        // Then
        XCTAssertEqual(try Data(contentsOf: conversationURL), corruptData)
    }

    func test_loadSnapshot_symlinkedAttachmentRoot_throwsWithoutReadingExternalFiles() throws {
        // Given
        let outsideDirectory = rootURL.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        let sentinelURL = outsideDirectory.appendingPathComponent("sentinel")
        try Data("sentinel".utf8).write(to: sentinelURL)
        try FileManager.default.createDirectory(at: cloudDocumentsURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: cloudDocumentsURL.appendingPathComponent("Attachments", isDirectory: true),
            withDestinationURL: outsideDirectory
        )

        // When / Then
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .invalidAttachmentPath)
        }
        XCTAssertEqual(try Data(contentsOf: sentinelURL), Data("sentinel".utf8))
    }

    func test_loadSnapshot_deleteAllPlaceholder_throwsPendingDownload() throws {
        // Given
        try FileManager.default.createDirectory(at: cloudDocumentsURL, withIntermediateDirectories: true)
        let placeholder = cloudDocumentsURL.appendingPathComponent(".ConversationDeleteAll.json.icloud")
        try Data().write(to: placeholder)

        // When / Then
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }
    }

    func test_loadSnapshot_unreferencedAttachmentPlaceholder_doesNotBlock() throws {
        // Given
        let folder = cloudDocumentsURL
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent(".orphan.bin.icloud"))

        // When
        let snapshot = try sut.loadConversationSyncSnapshot()

        // Then
        XCTAssertTrue(snapshot.conversations.isEmpty)
    }

    func test_synchronize_unreferencedAttachmentPlaceholder_removesWithoutWaiting() async throws {
        // Given
        let folder = cloudDocumentsURL
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let placeholderURL = folder.appendingPathComponent(".orphan.bin.icloud")
        try Data().write(to: placeholderURL)
        let repository = makeRepository(localDocuments: localDocumentsURL)

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertFalse(FileManager.default.fileExists(atPath: placeholderURL.path))
    }

    func test_applySnapshot_cloudChangedAfterRead_throwsWithoutOverwriting() throws {
        // Given
        let original = Conversation(title: "Original", modelId: "model")
        try writeCloudConversation(original)
        let snapshot = try sut.loadConversationSyncSnapshot()
        var remoteUpdate = original
        remoteUpdate.title = "Remote update"
        remoteUpdate.updatedAt = original.updatedAt.addingTimeInterval(1)
        try writeCloudConversation(remoteUpdate)

        // When
        XCTAssertThrowsError(
            try sut.applyConversationSyncOutput(output(conversations: [original]), basedOn: snapshot)
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
        }

        // Then
        XCTAssertEqual(try readCloudConversation(original.id).title, "Remote update")
    }

    func test_applySnapshot_identityChanged_throwsWithoutWriting() throws {
        // Given
        let provider = MutableCloudContainerProvider(url: cloudContainerURL, identity: Data("A".utf8))
        sut = CloudSyncManager(containerProvider: provider)
        let snapshot = try sut.loadConversationSyncSnapshot()
        let conversation = Conversation(modelId: "model")
        provider.setIdentity(Data("B".utf8))

        // When
        XCTAssertThrowsError(
            try sut.applyConversationSyncOutput(output(conversations: [conversation]), basedOn: snapshot)
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .containerIdentityChanged)
        }

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudConversationURL(for: conversation.id).path))
    }

    func test_loadSnapshot_identityChangedWithoutNewBaseline_throwsPendingDownload() throws {
        // Given
        let provider = MutableCloudContainerProvider(url: cloudContainerURL, identity: Data("A".utf8))
        sut = CloudSyncManager(containerProvider: provider)
        _ = try sut.loadConversationSyncSnapshot()
        provider.setIdentity(Data("B".utf8))

        // When / Then
        XCTAssertThrowsError(try sut.loadConversationSyncSnapshot()) { error in
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }
    }

    func test_applySnapshot_metadataReadinessReset_throwsWithoutWriting() throws {
        // Given
        let provider = MutableCloudContainerProvider(url: cloudContainerURL, identity: Data("A".utf8))
        sut = CloudSyncManager(containerProvider: provider)
        let snapshot = try sut.loadConversationSyncSnapshot()
        let conversation = Conversation(modelId: "model")
        provider.setMetadataReady(false)

        // When
        XCTAssertThrowsError(
            try sut.applyConversationSyncOutput(output(conversations: [conversation]), basedOn: snapshot)
        ) { error in
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudConversationURL(for: conversation.id).path))
    }

    func test_synchronize_secondDevice_materializesExactAttachmentBytes() async throws {
        // Given
        let bytes = Data([0x01, 0x02, 0x03])
        let conversation = makeConversationWithAttachment(updatedAt: Date())
        try writeLocalConversation(conversation, to: localDocumentsURL)
        try writeAttachment(bytes, conversation: conversation, to: localDocumentsURL)
        let firstRepository = makeRepository(localDocuments: localDocumentsURL)
        let firstResult = await firstRepository.synchronize()
        XCTAssertEqual(firstResult, .synchronized)
        let secondDeviceURL = rootURL.appendingPathComponent("SecondDevice", isDirectory: true)
        try FileManager.default.createDirectory(at: secondDeviceURL, withIntermediateDirectories: true)
        let secondRepository = makeRepository(localDocuments: secondDeviceURL)

        // When
        let result = await secondRepository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertEqual(try attachmentData(for: conversation, in: secondDeviceURL), bytes)
    }

    func test_synchronize_cloudWinner_replacesStaleLocalAttachmentBytes() async throws {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let localConversation = makeConversationWithAttachment(updatedAt: timestamp)
        var cloudConversation = localConversation
        cloudConversation.updatedAt = timestamp.addingTimeInterval(1)
        let key = try XCTUnwrap(try ConversationAttachmentPath.key(
            for: try XCTUnwrap(cloudConversation.messages.first?.attachments.first),
            conversationId: cloudConversation.id
        ))
        let snapshot = try sut.loadConversationSyncSnapshot()
        try sut.applyConversationSyncOutput(
            output(conversations: [cloudConversation], attachments: [key: Data("cloud".utf8)]),
            basedOn: snapshot
        )
        try writeLocalConversation(localConversation, to: localDocumentsURL)
        try writeAttachment(Data("local".utf8), conversation: localConversation, to: localDocumentsURL)
        let repository = makeRepository(localDocuments: localDocumentsURL)

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertEqual(try attachmentData(for: localConversation, in: localDocumentsURL), Data("cloud".utf8))
        XCTAssertEqual(try sut.loadConversationSyncSnapshot().attachmentData[key], Data("cloud".utf8))
        let recoveryFiles = try attachmentRecoveryData(for: localConversation.id)
        XCTAssertTrue(recoveryFiles.contains(Data("local".utf8)))
    }

    func test_synchronize_missingLocalAttachment_doesNotPublishParent() async throws {
        // Given
        let conversation = makeConversationWithAttachment(updatedAt: Date())
        try writeLocalConversation(conversation, to: localDocumentsURL)
        let repository = makeRepository(localDocuments: localDocumentsURL)

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .failed)
        XCTAssertNil(try sut.loadConversationSyncSnapshot().conversations[conversation.id])
    }

    func test_synchronize_unchangedInputs_doesNotCreateAnotherLocalTransaction() async throws {
        // Given
        let conversation = Conversation(modelId: "model")
        try writeLocalConversation(conversation, to: localDocumentsURL)
        let repository = makeRepository(localDocuments: localDocumentsURL)
        let initialResult = await repository.synchronize()
        XCTAssertEqual(initialResult, .synchronized)
        let transactionsURL = localDocumentsURL
            .appendingPathComponent("ConversationRecovery", isDirectory: true)
            .appendingPathComponent("Transactions", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: transactionsURL.path))

        // When
        let result = await repository.synchronize()

        // Then
        XCTAssertEqual(result, .synchronized)
        XCTAssertFalse(FileManager.default.fileExists(atPath: transactionsURL.path))
    }
}

// MARK: - Private

private extension CloudSyncManagerConversationTests {
    var cloudDocumentsURL: URL {
        cloudContainerURL.appendingPathComponent("Documents", isDirectory: true)
    }

    var cloudConversationsURL: URL {
        cloudDocumentsURL.appendingPathComponent("Conversations", isDirectory: true)
    }

    func makeManager() -> CloudSyncManager {
        CloudSyncManager(containerProvider: FixedCloudContainerProvider(url: cloudContainerURL))
    }

    func makeRepository(localDocuments: URL) -> ConversationRepository {
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        return ConversationRepository(
            settingsManager: settingsManager,
            cloudSyncManager: makeManager(),
            attachmentRepository: AttachmentRepository(baseURL: localDocuments),
            baseDirectory: localDocuments
        )
    }

    func output(
        conversations: [Conversation],
        attachments: [CloudAttachmentKey: Data] = [:]
    ) throws -> ConversationCloudSyncOutput {
        let encoder = SyncJSONCoding.makeEncoder()
        let encodedConversations = try conversations.map { conversation in
            (conversation.id, try encoder.encode(conversation))
        }
        let conversationData = Dictionary(uniqueKeysWithValues: encodedConversations)
        let decoder = SyncJSONCoding.makeDecoder()
        let canonicalConversations = try conversationData.values.map {
            try decoder.decode(Conversation.self, from: $0)
        }
        return ConversationCloudSyncOutput(
            conversations: canonicalConversations,
            conversationData: conversationData,
            tombstones: [],
            deleteAllMarker: nil,
            attachments: attachments
        )
    }

    func cloudConversationURL(for id: UUID) -> URL {
        cloudConversationsURL.appendingPathComponent("\(id.uuidString).json")
    }

    func writeCloudConversation(_ conversation: Conversation) throws {
        let url = cloudConversationURL(for: conversation.id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try SyncJSONCoding.makeEncoder().encode(conversation).write(to: url, options: .atomic)
    }

    func readCloudConversation(_ id: UUID) throws -> Conversation {
        let data = try Data(contentsOf: cloudConversationURL(for: id))
        return try SyncJSONCoding.makeDecoder().decode(Conversation.self, from: data)
    }

    func makeConversationWithAttachment(updatedAt: Date) -> Conversation {
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

    func writeLocalConversation(_ conversation: Conversation, to documentsURL: URL) throws {
        let directory = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SyncJSONCoding.makeEncoder().encode(conversation).write(
            to: directory.appendingPathComponent("\(conversation.id.uuidString).json"),
            options: .atomic
        )
    }

    func writeAttachment(_ data: Data, conversation: Conversation, to documentsURL: URL) throws {
        let attachment = try XCTUnwrap(conversation.messages.first?.attachments.first)
        let url = documentsURL.appendingPathComponent(attachment.fileRelativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func attachmentData(for conversation: Conversation, in documentsURL: URL) throws -> Data {
        let attachment = try XCTUnwrap(conversation.messages.first?.attachments.first)
        return try Data(contentsOf: documentsURL.appendingPathComponent(attachment.fileRelativePath))
    }

    func attachmentRecoveryData(for conversationId: UUID) throws -> [Data] {
        let directory = localDocumentsURL
            .appendingPathComponent("ConversationRecovery/Attachments", isDirectory: true)
            .appendingPathComponent(conversationId.uuidString, isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files.map { try Data(contentsOf: $0) }
    }
}

// Safety: Mutable state is protected by `lock`; `url` is immutable.
nonisolated private final class MutableCloudContainerProvider: CloudContainerProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var identity: Data
    private var readyIdentity: Data

    init(url: URL, identity: Data) {
        self.url = url
        self.identity = identity
        self.readyIdentity = identity
    }

    func isAvailable() -> Bool { true }
    func isMetadataReady(for session: CloudSyncSession) -> Bool {
        lock.withLock { readyIdentity == session.identity }
    }
    func containerURL() -> URL? { url }
    func identityData() -> Data? { lock.withLock { identity } }
    func setIdentity(_ identity: Data) { lock.withLock { self.identity = identity } }
    func setMetadataReady(_ isReady: Bool) {
        lock.withLock { readyIdentity = isReady ? identity : Data() }
    }
}
