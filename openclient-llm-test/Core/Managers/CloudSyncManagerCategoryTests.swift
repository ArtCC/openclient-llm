//
//  CloudSyncManagerCategoryTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncManagerCategoryTests: XCTestCase {
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

    func test_readCoordinator_calledFromMainActor_runsAccessorOffMainThread() async throws {
        // Given
        let fileURL = rootURL.appendingPathComponent("Coordinated.json")
        try Data().write(to: fileURL)

        // When
        let accessorRanOnMainThread = try await CloudFileCoordinator().read(at: fileURL) { _ in
            Thread.isMainThread
        }

        // Then
        XCTAssertFalse(accessorRanOnMainThread)
    }

    func test_saveProfile_accountChangesDuringCoordination_performsNoWrite() async throws {
        // Given
        let provider = SwitchingCloudContainerProvider(url: rootURL)
        let sut = CloudSyncManager(containerProvider: provider)
        let snapshot = CloudUserProfileSnapshot(
            session: CloudSyncSession(containerURL: rootURL, identity: Data("first".utf8)),
            state: .missing,
            profileData: nil,
            deletionMarkerData: nil
        )

        // When
        do {
            try await sut.applyProfileSyncOutput(.profile(UserProfile(name: "Local")), basedOn: snapshot)
            XCTFail("Expected identity change")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerIdentityChanged)
        }

        // Then
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("UserProfile.json").path
        ))
    }

    func test_loadProfile_placeholderPresent_reportsPendingInsteadOfMissing() async throws {
        // Given
        let placeholderURL = documentsURL.appendingPathComponent(".UserProfile.json.icloud")
        try Data().write(to: placeholderURL)
        let sut = makeManager()

        // When
        do {
            _ = try await sut.loadProfileSyncSnapshot()
            XCTFail("Expected pending download")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }
    }

    func test_loadProfileState_deletionNewerThanPayload_exposesDeletionIntent() async throws {
        // Given
        let profile = UserProfile(name: "Stale", modifiedAt: Date(timeIntervalSince1970: 100))
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        try encode(profile).write(to: documentsURL.appendingPathComponent("UserProfile.json"), options: .atomic)
        try encode(marker).write(
            to: documentsURL.appendingPathComponent("UserProfileDeletion.json"),
            options: .atomic
        )

        // When
        let state = try await makeManager().loadProfileSyncSnapshot().state

        // Then
        XCTAssertEqual(state, .deleted(marker))
    }

    func test_loadProfileState_payloadNewerThanDeletionMarker_allowsRecreation() async throws {
        // Given
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 100)
        )
        let profile = UserProfile(name: "Recreated", modifiedAt: Date(timeIntervalSince1970: 200))
        try encode(marker).write(
            to: documentsURL.appendingPathComponent("UserProfileDeletion.json"),
            options: .atomic
        )
        try encode(profile).write(to: documentsURL.appendingPathComponent("UserProfile.json"), options: .atomic)

        // When
        let state = try await makeManager().loadProfileSyncSnapshot().state

        // Then
        XCTAssertEqual(state, .profile(profile))
    }

    func test_saveProfile_revisionNotNewerThanDeletion_rejectsStaleResurrection() async throws {
        // Given
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        try encode(marker).write(
            to: documentsURL.appendingPathComponent("UserProfileDeletion.json"),
            options: .atomic
        )
        let stale = UserProfile(name: "Stale", modifiedAt: Date(timeIntervalSince1970: 100))
        let sut = makeManager()
        let snapshot = try await sut.loadProfileSyncSnapshot()

        // When
        do {
            try await sut.applyProfileSyncOutput(.profile(stale), basedOn: snapshot)
            XCTFail("Expected stale profile rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .staleProfileRevision)
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: documentsURL.appendingPathComponent("UserProfile.json").path
            ))
        }
    }

    func test_saveProfile_revisionNewerThanDeletion_recreatesAndRetainsMarker() async throws {
        // Given
        let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 100)
        )
        try encode(marker).write(to: markerURL, options: .atomic)
        let recreated = UserProfile(name: "Recreated", modifiedAt: Date(timeIntervalSince1970: 200))
        let sut = makeManager()
        let snapshot = try await sut.loadProfileSyncSnapshot()

        // When
        try await sut.applyProfileSyncOutput(.profile(recreated), basedOn: snapshot)

        // Then
        let state = try await sut.loadProfileSyncSnapshot().state
        XCTAssertEqual(state, .profile(recreated))
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func test_deleteMemoryItem_stalePayloadReappears_tombstonePreventsResurrection() async throws {
        // Given
        let item = MemoryItem(content: "Forget me")
        let sut = makeManager()
        try encode([item]).write(to: documentsURL.appendingPathComponent("Memory.json"), options: .atomic)
        try await sut.deleteMemoryItemFromCloud(item.id, deletedAt: Date())
        try encode([item]).write(to: documentsURL.appendingPathComponent("Memory.json"), options: .atomic)

        // When
        let loaded = try await sut.loadMemorySyncSnapshot().items

        // Then
        XCTAssertEqual(loaded, [])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("MemoryTombstones.json").path
        ))
    }

    func test_deleteMemoryItem_newerPayloadExists_retainsRecreatedItemAndTombstone() async throws {
        // Given
        let id = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_000)
        let recreated = MemoryItem(
            id: id,
            content: "Recreated",
            createdAt: deletedAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        let sut = makeManager()
        try encode([recreated]).write(to: documentsURL.appendingPathComponent("Memory.json"), options: .atomic)

        // When
        try await sut.deleteMemoryItemFromCloud(id, deletedAt: deletedAt)
        let snapshot = try await sut.loadMemorySyncSnapshot()

        // Then
        XCTAssertEqual(snapshot.items, [recreated])
        XCTAssertEqual(snapshot.deletionMarkers, [CloudDeletionMarker(id: id, deletedAt: deletedAt)])
    }

    func test_deleteTemplate_stalePayloadReappears_tombstonePreventsResurrection() async throws {
        // Given
        let template = PromptTemplate(title: "Deleted", content: "Body")
        let sut = makeManager()
        try seedTemplate(template)
        let snapshot = try await sut.loadTemplatesFromCloud()
        let marker = CloudDeletionMarker(id: template.id, deletedAt: Date())
        try await sut.applyTemplateDeletion(marker, basedOn: snapshot)
        let payloadURL = documentsURL.appendingPathComponent("PromptTemplates/\(template.id.uuidString).json")
        try encode(template).write(to: payloadURL, options: .atomic)

        // When
        let loaded = try await sut.loadTemplatesFromCloud()

        // Then
        XCTAssertTrue(loaded.templates.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent(
                "PromptTemplateTombstones/\(template.id.uuidString).json"
            ).path
        ))
    }

    func test_syncTemplate_revisionNewerThanTombstone_allowsRecreation() async throws {
        // Given
        let id = UUID()
        let deletedAt = Date(timeIntervalSince1970: 2_000)
        let recreated = PromptTemplate(
            id: id,
            title: "Recreated",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        let sut = makeManager()
        let deletionSnapshot = try await sut.loadTemplatesFromCloud()
        try await sut.applyTemplateDeletion(
            CloudDeletionMarker(id: id, deletedAt: deletedAt),
            basedOn: deletionSnapshot
        )
        let snapshot = try await sut.loadTemplatesFromCloud()

        // When
        try await sut.applyTemplateUploads([recreated], basedOn: snapshot)
        let currentSnapshot = try await sut.loadTemplatesFromCloud()

        // Then
        XCTAssertEqual(currentSnapshot.templates, [recreated])
        XCTAssertEqual(currentSnapshot.deletionMarkers[id]?.deletedAt, deletedAt)
    }

    // MARK: - Private

    private func makeManager() -> CloudSyncManager {
        CloudSyncManager(containerProvider: FixedCloudContainerProvider(url: rootURL))
    }

    private func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func seedTemplate(_ template: PromptTemplate) throws {
        let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(template).write(
            to: directory.appendingPathComponent("\(template.id.uuidString).json"),
            options: .atomic
        )
    }
}

// Safety: Mutable call state is protected by `lock`; `url` is immutable.
nonisolated private final class SwitchingCloudContainerProvider: CloudContainerProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var sessionCallCount = 0

    init(url: URL) {
        self.url = url
    }

    func isAvailable() -> Bool { true }
    func isMetadataReady(for session: CloudSyncSession) -> Bool { true }
    func containerURL() -> URL? { url }
    func identityData() -> Data? { Data("first".utf8) }

    func currentSession() -> CloudSyncSession? {
        lock.withLock {
            sessionCallCount += 1
            let identity = sessionCallCount == 1 ? Data("first".utf8) : Data("second".utf8)
            return CloudSyncSession(containerURL: url, identity: identity)
        }
    }
}
