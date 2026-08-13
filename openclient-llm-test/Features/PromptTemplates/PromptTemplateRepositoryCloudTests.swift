//
//  PromptTemplateRepositoryCloudTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class PromptTemplateRepositoryCloudTests: XCTestCase {
    func test_loadAll_localOnlyTemplate_uploadsAndKeepsLocalTemplate() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(
            title: "Local",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        try encode(template).write(to: templateURL(template.id, in: context.directoryURL), options: .atomic)

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == template.id }, template)
        XCTAssertEqual(context.cloud.cloudTemplates, [template])
    }

    func test_loadAll_cloudOnlyTemplate_downloadsAndKeepsCloudTemplate() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(
            title: "Cloud",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        context.cloud.cloudTemplates = [template]

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == template.id }, template)
        XCTAssertEqual(try decodeTemplate(at: templateURL(template.id, in: context.directoryURL)), template)
        XCTAssertTrue(context.cloud.syncedTemplates.isEmpty)
    }

    func test_loadAll_legacyTemplate_migratesUpdatedAtFromCreatedAt() async throws {
        // Given
        let context = try makeContext(cloudEnabled: false)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let template = PromptTemplate(id: UUID(), title: "Legacy", content: "Body", createdAt: createdAt)
        let legacyData = try legacyData(for: template)
        try legacyData.write(to: templateURL(template.id, in: context.directoryURL), options: .atomic)

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == template.id }?.updatedAt, createdAt)
        let migratedData = try Data(contentsOf: templateURL(template.id, in: context.directoryURL))
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: migratedData) as? [String: Any])
        let migratedJSON = try XCTUnwrap(String(data: migratedData, encoding: .utf8))
        XCTAssertTrue(migratedJSON.contains("updatedAt"))
    }

    func test_loadAll_equalRevisionConflict_usesDeterministicWinnerAndPreservesLoser() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let revision = Date(timeIntervalSince1970: 2_000)
        let local = PromptTemplate(
            id: id,
            title: "Local",
            content: "Body",
            createdAt: createdAt,
            updatedAt: revision
        )
        let cloud = PromptTemplate(
            id: id,
            title: "Cloud",
            content: "Body",
            createdAt: createdAt,
            updatedAt: revision
        )
        let localData = try encode(local)
        let cloudData = try encode(cloud)
        try localData.write(to: templateURL(id, in: context.directoryURL), options: .atomic)
        context.cloud.cloudTemplates = [cloud]
        let expected = cloudData.lexicographicallyPrecedes(localData) ? local : cloud

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == id }, expected)
        let recoveryURL = context.rootURL.appendingPathComponent("PromptTemplateRecovery", isDirectory: true)
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: recoveryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(recoveryFiles.filter { $0.pathExtension == "json" }.count, 1)
    }

    func test_loadAll_cloudRevisionNewerThanLocal_usesCloudAndPreservesLocal() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 500)
        let local = PromptTemplate(
            id: id,
            title: "Local",
            content: "Body",
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let cloud = PromptTemplate(
            id: id,
            title: "Cloud",
            content: "Body",
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        try encode(local).write(to: templateURL(id, in: context.directoryURL), options: .atomic)
        context.cloud.cloudTemplates = [cloud]

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == id }, cloud)
        XCTAssertEqual(try decodeTemplate(at: templateURL(id, in: context.directoryURL)), cloud)
        XCTAssertEqual(try recoveryFileCount(in: context.rootURL), 1)
        XCTAssertTrue(context.cloud.syncedTemplates.isEmpty)
    }

    func test_loadAll_corruptLocalTemplate_reportsErrorAndPreservesFile() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let corruptURL = templateURL(UUID(), in: context.directoryURL)
        let corruptData = Data("not-json".utf8)
        try corruptData.write(to: corruptURL, options: .atomic)

        // When
        do {
            _ = try await context.repository.loadAll()
            XCTFail("Expected invalid local template error")
        } catch {
            // Then
            XCTAssertEqual(try Data(contentsOf: corruptURL), corruptData)
            XCTAssertTrue(context.cloud.syncedTemplates.isEmpty)
        }
    }

    func test_loadAll_mismatchedLocalTombstoneId_reportsErrorAndPreservesFile() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let fileID = UUID()
        let marker = CloudDeletionMarker(id: UUID(), deletedAt: Date(timeIntervalSince1970: 2_000))
        let markerDirectory = context.directoryURL.appendingPathComponent(".DeletionMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
        let markerURL = markerDirectory.appendingPathComponent("\(fileID.uuidString).json")
        let markerData = try encode(marker)
        try markerData.write(to: markerURL, options: .atomic)

        // When
        do {
            _ = try await context.repository.loadAll()
            XCTFail("Expected invalid local tombstone error")
        } catch {
            // Then
            XCTAssertEqual(try Data(contentsOf: markerURL), markerData)
            XCTAssertTrue(context.cloud.deletedTemplateIds.isEmpty)
        }
    }

    func test_loadAll_cloudTombstoneNewerThanLocal_removesStaleLocalCopy() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(
            id: UUID(),
            title: "Stale",
            content: "Body",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        try encode(template).write(to: templateURL(template.id, in: context.directoryURL), options: .atomic)
        context.cloud.cloudTemplateDeletionMarkers[template.id] = CloudDeletionMarker(
            id: template.id,
            deletedAt: Date(timeIntervalSince1970: 2_000)
        )

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertFalse(loaded.contains { $0.id == template.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: templateURL(template.id, in: context.directoryURL).path))
    }

    func test_loadAll_localRevisionNewerThanCloudTombstone_recreatesTemplate() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(
            id: UUID(),
            title: "Recreated",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        try encode(template).write(to: templateURL(template.id, in: context.directoryURL), options: .atomic)
        context.cloud.cloudTemplateDeletionMarkers[template.id] = CloudDeletionMarker(
            id: template.id,
            deletedAt: Date(timeIntervalSince1970: 2_000)
        )

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertEqual(loaded.first { $0.id == template.id }, template)
        XCTAssertEqual(context.cloud.cloudTemplates, [template])
        XCTAssertEqual(
            context.cloud.cloudTemplateDeletionMarkers[template.id]?.deletedAt,
            Date(timeIntervalSince1970: 2_000)
        )
        XCTAssertEqual(
            try decodeMarker(template.id, in: context.directoryURL)?.deletedAt,
            Date(timeIntervalSince1970: 2_000)
        )
    }

    func test_save_staleInputWithNewerCloud_preservesCloudAndWritesCausallyNewRevision() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let id = UUID()
        let cloudRevision = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.up) + 10_000)
        let cloud = PromptTemplate(
            id: id,
            title: "Cloud edit",
            content: "Cloud body",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: cloudRevision
        )
        let staleSave = PromptTemplate(
            id: id,
            title: "Local edit",
            content: "Local body",
            createdAt: cloud.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        context.cloud.cloudTemplates = [cloud]

        // When
        try await context.repository.save(staleSave)

        // Then
        let saved = try XCTUnwrap(context.cloud.cloudTemplates.first { $0.id == id })
        XCTAssertEqual(saved.title, staleSave.title)
        XCTAssertEqual(saved.content, staleSave.content)
        XCTAssertGreaterThan(saved.updatedAt, cloudRevision)
        XCTAssertEqual(try recoveryFileCount(in: context.rootURL), 1)
    }

    func test_save_recreatingDeletedTemplate_advancesBeyondTombstone() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let id = UUID()
        let deletionRevision = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.up) + 10_000)
        context.cloud.cloudTemplateDeletionMarkers[id] = CloudDeletionMarker(id: id, deletedAt: deletionRevision)
        let recreated = PromptTemplate(
            id: id,
            title: "Recreated",
            content: "Body",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        // When
        try await context.repository.save(recreated)

        // Then
        let saved = try XCTUnwrap(context.cloud.cloudTemplates.first { $0.id == id })
        XCTAssertGreaterThan(saved.updatedAt, deletionRevision)
        XCTAssertEqual(context.cloud.cloudTemplateDeletionMarkers[id]?.deletedAt, deletionRevision)
        XCTAssertEqual(try decodeMarker(id, in: context.directoryURL)?.deletedAt, deletionRevision)
    }

    func test_delete_newerCloudTemplate_createsCausallyNewerTombstone() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let cloudRevision = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.up) + 10_000)
        let template = PromptTemplate(
            title: "Cloud",
            content: "Body",
            updatedAt: cloudRevision
        )
        context.cloud.cloudTemplates = [template]

        // When
        try await context.repository.delete(template.id)

        // Then
        let marker = try XCTUnwrap(context.cloud.cloudTemplateDeletionMarkers[template.id])
        XCTAssertGreaterThan(marker.deletedAt, cloudRevision)
        XCTAssertFalse(context.cloud.cloudTemplates.contains { $0.id == template.id })
    }

    func test_loadAll_unchangedReconciliation_doesNotRewriteLocalOrCloudTemplate() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(
            title: "Stable",
            content: "Body",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        context.cloud.cloudTemplates = [template]
        _ = try await context.repository.loadAll()
        let localURL = templateURL(template.id, in: context.directoryURL)
        let sentinel = Date(timeIntervalSince1970: 123)
        try FileManager.default.setAttributes([.modificationDate: sentinel], ofItemAtPath: localURL.path)
        let initialCloudWrites = context.cloud.syncedTemplates.count

        // When
        _ = try await context.repository.loadAll()

        // Then
        let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        XCTAssertEqual(attributes[.modificationDate] as? Date, sentinel)
        XCTAssertEqual(context.cloud.syncedTemplates.count, initialCloudWrites)
    }

    func test_delete_cloudUnavailable_throwsWithoutChangingCanonicalLocalPayload() async throws {
        // Given
        let context = try makeContext(cloudEnabled: false)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(title: "Deleted", content: "Body")
        try await context.repository.save(template)
        context.settings.isCloudSyncEnabled = true
        context.cloud.cloudAvailable = false

        // When
        do {
            try await context.repository.delete(template.id)
            XCTFail("Expected cloud delete failure")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerUnavailable)
        }
        let markerURL = context.directoryURL
            .appendingPathComponent(".DeletionMetadata/\(template.id.uuidString).json")

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: templateURL(template.id, in: context.directoryURL).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL.path))
    }

}

// MARK: - Private

extension PromptTemplateRepositoryCloudTests {
    struct TestContext {
        let rootURL: URL
        let directoryURL: URL
        let cloud: MockCloudSyncManager
        let settings: MockSettingsManager
        let operationGate: PromptTemplateOperationGate
        let repository: PromptTemplateRepository
    }

    func makeContext(cloudEnabled: Bool) throws -> TestContext {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directoryURL = rootURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let settings = MockSettingsManager()
        settings.isCloudSyncEnabled = cloudEnabled
        let cloud = MockCloudSyncManager()
        let operationGate = PromptTemplateOperationGate()
        return TestContext(
            rootURL: rootURL,
            directoryURL: directoryURL,
            cloud: cloud,
            settings: settings,
            operationGate: operationGate,
            repository: PromptTemplateRepository(
                settingsManager: settings,
                cloudSyncManager: cloud,
                directoryURL: directoryURL,
                operationGate: operationGate
            )
        )
    }

    func templateURL(_ id: UUID, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    func decodeTemplate(at url: URL) throws -> PromptTemplate {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PromptTemplate.self, from: Data(contentsOf: url))
    }

    func decodeMarker(_ id: UUID, in directoryURL: URL) throws -> CloudDeletionMarker? {
        let url = directoryURL.appendingPathComponent(".DeletionMetadata/\(id.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CloudDeletionMarker.self, from: Data(contentsOf: url))
    }

    func recoveryFileCount(in rootURL: URL) throws -> Int {
        let recoveryURL = rootURL.appendingPathComponent("PromptTemplateRecovery", isDirectory: true)
        return try FileManager.default.contentsOfDirectory(at: recoveryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .count
    }

    func legacyData(for template: PromptTemplate) throws -> Data {
        let formatter = ISO8601DateFormatter()
        return try JSONSerialization.data(withJSONObject: [
            "id": template.id.uuidString,
            "title": template.title,
            "content": template.content,
            "isBuiltIn": template.isBuiltIn,
            "createdAt": formatter.string(from: template.createdAt)
        ])
    }
}
