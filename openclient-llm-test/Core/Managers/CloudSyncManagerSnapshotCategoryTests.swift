//
//  CloudSyncManagerSnapshotCategoryTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncManagerSnapshotCategoryTests: XCTestCase {
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

    func test_applyProfileSyncOutput_profileBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let original = UserProfile(name: "Original", modifiedAt: Date(timeIntervalSince1970: 100))
        let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
        try encode(original).write(to: profileURL, options: .atomic)
        let snapshot = try await sut.loadProfileSyncSnapshot()
        let concurrent = UserProfile(name: "Concurrent", modifiedAt: Date(timeIntervalSince1970: 200))
        let concurrentData = try encode(concurrent)
        try concurrentData.write(to: profileURL, options: .atomic)

        // When
        do {
            try await sut.applyProfileSyncOutput(.profile(original), basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: profileURL), concurrentData)
        }
    }

    func test_applyProfileSyncOutput_markerBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let profile = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 300))
        let snapshot = try await sut.loadProfileSyncSnapshot()
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
        let concurrentData = try encode(marker)
        try concurrentData.write(to: markerURL, options: .atomic)

        // When
        do {
            try await sut.applyProfileSyncOutput(.profile(profile), basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: markerURL), concurrentData)
        }
    }

    func test_applyMemorySyncOutput_memoryBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let original = MemoryItem(content: "Original")
        try encode([original]).write(to: documentsURL.appendingPathComponent("Memory.json"), options: .atomic)
        let snapshot = try await sut.loadMemorySyncSnapshot()
        let concurrent = MemoryItem(content: "Concurrent")
        let memoryURL = documentsURL.appendingPathComponent("Memory.json")
        let concurrentData = try SyncJSONCoding.makeEncoder().encode([concurrent])
        try concurrentData.write(to: memoryURL, options: .atomic)

        // When
        do {
            try await sut.applyMemorySyncOutput(
                items: [original],
                deletionMarkers: [],
                basedOn: snapshot
            )
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: memoryURL), concurrentData)
        }
    }

    func test_applyMemorySyncOutput_tombstoneBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let snapshot = try await sut.loadMemorySyncSnapshot()
        let marker = CloudDeletionMarker(id: UUID(), deletedAt: Date())
        let markerURL = documentsURL.appendingPathComponent("MemoryTombstones.json")
        let concurrentData = try SyncJSONCoding.makeEncoder().encode([marker])
        try concurrentData.write(to: markerURL, options: .atomic)

        // When
        do {
            try await sut.applyMemorySyncOutput(items: [], deletionMarkers: [], basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: markerURL), concurrentData)
        }
    }

    func test_applyTemplateUploads_templateBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let original = PromptTemplate(title: "Original", content: "Body")
        try seedTemplate(original)
        let snapshot = try await sut.loadTemplatesFromCloud()
        let concurrent = PromptTemplate(id: original.id, title: "Concurrent", content: "Body")
        let templateURL = documentsURL.appendingPathComponent(
            "PromptTemplates/\(original.id.uuidString).json"
        )
        let concurrentData = try encode(concurrent)
        try concurrentData.write(to: templateURL, options: .atomic)

        // When
        do {
            try await sut.applyTemplateUploads([original], basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: templateURL), concurrentData)
        }
    }

    func test_applyTemplateUploads_tombstoneBytesChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let upload = PromptTemplate(title: "Upload", content: "Body")
        let snapshot = try await sut.loadTemplatesFromCloud()
        let marker = CloudDeletionMarker(id: UUID(), deletedAt: Date())
        let directory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let markerURL = directory.appendingPathComponent("\(marker.id.uuidString).json")
        let concurrentData = try encode(marker)
        try concurrentData.write(to: markerURL, options: .atomic)

        // When
        do {
            try await sut.applyTemplateUploads([upload], basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertEqual(try Data(contentsOf: markerURL), concurrentData)
        }
    }

    func test_applyTemplateUploads_newerRecreation_retainsDurableTombstone() async throws {
        // Given
        let sut = makeManager()
        let id = UUID()
        let marker = CloudDeletionMarker(id: id, deletedAt: Date(timeIntervalSince1970: 100))
        try seedTemplateMarker(marker)
        let snapshot = try await sut.loadTemplatesFromCloud()
        let template = PromptTemplate(
            id: id,
            title: "Recreated",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        // When
        try await sut.applyTemplateUploads([template], basedOn: snapshot)
        let current = try await sut.loadTemplatesFromCloud()

        // Then
        XCTAssertEqual(current.templates, [template])
        XCTAssertEqual(current.deletionMarkers[id], marker)
    }

    func test_applyTemplateDeletion_stalePayloadAndEqualMarker_removesOnlyPayload() async throws {
        // Given
        let sut = makeManager()
        let revision = Date(timeIntervalSince1970: 100)
        let template = PromptTemplate(title: "Stale", content: "Body", updatedAt: revision)
        let marker = CloudDeletionMarker(id: template.id, deletedAt: revision)
        try seedTemplate(template)
        try seedTemplateMarker(marker)
        let snapshot = try await sut.loadTemplatesFromCloud()

        // When
        try await sut.applyTemplateDeletion(marker, basedOn: snapshot)
        let current = try await sut.loadTemplatesFromCloud()

        // Then
        XCTAssertNil(current.rawTemplates[template.id])
        XCTAssertEqual(current.deletionMarkers[template.id], marker)
    }

    func test_applyTemplateDeletion_directoryChanged_rejectsStaleSnapshot() async throws {
        // Given
        let sut = makeManager()
        let template = PromptTemplate(title: "Delete", content: "Body")
        try seedTemplate(template)
        let snapshot = try await sut.loadTemplatesFromCloud()
        let concurrentMarker = CloudDeletionMarker(id: UUID(), deletedAt: Date())
        try seedTemplateMarker(concurrentMarker)
        let marker = CloudDeletionMarker(id: template.id, deletedAt: Date())

        // When
        do {
            try await sut.applyTemplateDeletion(marker, basedOn: snapshot)
            XCTFail("Expected stale snapshot rejection")
        } catch {
            // Then
            let current = try await sut.loadTemplatesFromCloud()
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
            XCTAssertNotNil(current.rawTemplates[template.id])
        }
    }

    func test_loadTemplates_templateDirectoryPlaceholder_reportsPendingDownload() async throws {
        // Given
        try Data().write(to: documentsURL.appendingPathComponent(".PromptTemplates.icloud"))

        // When / Then
        await assertTemplateLoadRequiresDownload()
    }

    func test_loadTemplates_tombstoneDirectoryPlaceholder_reportsPendingDownload() async throws {
        // Given
        try Data().write(to: documentsURL.appendingPathComponent(".PromptTemplateTombstones.icloud"))

        // When / Then
        await assertTemplateLoadRequiresDownload()
    }

    func test_loadTemplates_mismatchedEmbeddedId_rejectsSnapshot() async throws {
        // Given
        let fileID = UUID()
        let template = PromptTemplate(id: UUID(), title: "Invalid", content: "Body")
        let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(template).write(
            to: directory.appendingPathComponent("\(fileID.uuidString).json"),
            options: .atomic
        )

        // When
        do {
            _ = try await makeManager().loadTemplatesFromCloud()
            XCTFail("Expected invalid template rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
        }
    }

    func test_loadTemplates_invalidFilename_rejectsSnapshot() async throws {
        // Given
        let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: directory.appendingPathComponent("template.json"))

        // When
        do {
            _ = try await makeManager().loadTemplatesFromCloud()
            XCTFail("Expected invalid filename rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .cloudContentChanged)
        }
    }

    func test_loadCloudInventory_pendingMemory_reportsFailureInsteadOfZero() async throws {
        // Given
        try Data().write(to: documentsURL.appendingPathComponent(".Memory.json.icloud"))

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        XCTAssertEqual(inventory.categories[.memory], .failed(.pendingDownload))
    }

    func test_loadCloudInventory_corruptMemory_reportsFailureInsteadOfZero() async throws {
        // Given
        try Data("invalid".utf8).write(to: documentsURL.appendingPathComponent("Memory.json"))

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        XCTAssertEqual(inventory.categories[.memory], .failed(.corruptData))
    }

    func test_loadCloudInventory_customTemplate_exposesOnlySanitizedLogicalFields() async throws {
        // Given
        let revision = Date(timeIntervalSince1970: 1_000)
        let template = PromptTemplate(
            title: "Visible",
            content: "Secret body",
            createdAt: revision,
            updatedAt: revision
        )
        try seedTemplate(template)

        // When
        let inventory = await makeManager().loadCloudInventory()

        // Then
        guard case .available(.promptTemplates(let items)) = inventory.categories[.promptTemplates] else {
            return XCTFail("Expected prompt-template inventory")
        }
        XCTAssertEqual(
            items,
            [CloudPromptTemplateInventoryItem(id: template.id, title: template.title, updatedAt: template.updatedAt)]
        )
    }

    func test_deleteCloudData_writesMarkerAboveKnownRevisionBeforeCleanup() async throws {
        // Given
        let revision = Date(timeIntervalSince1970: 1_000)
        let profile = UserProfile(name: "Delete", modifiedAt: revision)
        try encode(profile).write(to: documentsURL.appendingPathComponent("UserProfile.json"), options: .atomic)

        // When
        let result = try await makeManager().deleteCloudData(
            categories: Set(CloudDataCategory.allCases),
            marker: nil
        )

        // Then
        XCTAssertGreaterThan(result.marker.deletedAt, revision)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("UserProfile.json").path
        ))
        let marker = try SyncJSONCoding.makeDecoder().decode(
            CloudPurgeMarker.self,
            from: Data(contentsOf: documentsURL.appendingPathComponent("CloudPurgeMarker.json"))
        )
        XCTAssertEqual(marker, result.marker)
    }

    func test_deleteCloudData_retry_newerMemoryRecord_survives() async throws {
        // Given
        let manager = makeManager()
        let first = try await manager.deleteCloudData(
            categories: Set(CloudDataCategory.allCases),
            marker: nil
        )
        let revision = first.marker.deletedAt.addingTimeInterval(1)
        let item = MemoryItem(content: "Recreated", createdAt: revision, updatedAt: revision)
        try encode([item]).write(to: documentsURL.appendingPathComponent("Memory.json"), options: .atomic)

        // When
        _ = try await manager.deleteCloudData(categories: [.memory], marker: first.marker)

        // Then
        let stored = try SyncJSONCoding.makeDecoder().decode(
            [MemoryItem].self,
            from: Data(contentsOf: documentsURL.appendingPathComponent("Memory.json"))
        )
        XCTAssertEqual(stored, [item])
    }
}

// MARK: - Private

private extension CloudSyncManagerSnapshotCategoryTests {
    func makeManager() -> CloudSyncManager {
        CloudSyncManager(containerProvider: FixedCloudContainerProvider(url: rootURL))
    }

    func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    func assertTemplateLoadRequiresDownload() async {
        do {
            _ = try await makeManager().loadTemplatesFromCloud()
            XCTFail("Expected pending download")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
        }
    }

    func seedTemplate(_ template: PromptTemplate) throws {
        let directory = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(template).write(
            to: directory.appendingPathComponent("\(template.id.uuidString).json"),
            options: .atomic
        )
    }

    func seedTemplateMarker(_ marker: CloudDeletionMarker) throws {
        let directory = documentsURL.appendingPathComponent("PromptTemplateTombstones", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(marker).write(
            to: directory.appendingPathComponent("\(marker.id.uuidString).json"),
            options: .atomic
        )
    }
}
