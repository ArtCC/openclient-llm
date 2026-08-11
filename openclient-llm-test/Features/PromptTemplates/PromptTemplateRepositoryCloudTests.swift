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
        XCTAssertNil(context.cloud.cloudTemplateDeletionMarkers[template.id])
    }

    func test_delete_cloudFailure_retainsIntentAndRetriesBeforeCloudLoad() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(title: "Deleted", content: "Body")
        context.cloud.cloudTemplates = [template]
        try await context.repository.save(template)
        context.cloud.syncError = CloudSyncError.containerUnavailable

        // When
        do {
            try await context.repository.delete(template.id)
            XCTFail("Expected cloud delete failure")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerUnavailable)
        }
        do {
            _ = try await context.repository.loadAll()
            XCTFail("Expected retained deletion retry to fail")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerUnavailable)
        }
        let markerURL = context.directoryURL
            .appendingPathComponent(".DeletionMetadata/\(template.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))
        context.cloud.syncError = nil
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertFalse(loaded.contains { $0.id == template.id })
        XCTAssertGreaterThanOrEqual(context.cloud.deletedTemplateIds.filter { $0 == template.id }.count, 1)
    }

    // MARK: - Private

    private struct TestContext {
        let rootURL: URL
        let directoryURL: URL
        let cloud: MockCloudSyncManager
        let repository: PromptTemplateRepository
    }

    private func makeContext(cloudEnabled: Bool) throws -> TestContext {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directoryURL = rootURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let settings = MockSettingsManager()
        settings.isCloudSyncEnabled = cloudEnabled
        let cloud = MockCloudSyncManager()
        return TestContext(
            rootURL: rootURL,
            directoryURL: directoryURL,
            cloud: cloud,
            repository: PromptTemplateRepository(
                settingsManager: settings,
                cloudSyncManager: cloud,
                directoryURL: directoryURL
            )
        )
    }

    private func templateURL(_ id: UUID, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func encode(_ template: PromptTemplate) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(template)
    }

    private func legacyData(for template: PromptTemplate) throws -> Data {
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
