//
//  MemoryManagerCloudDeletionTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MemoryManagerCloudDeletionTests: XCTestCase {
    func test_delete_cloudFailure_retainsIntentAndRetriesWithoutResurrection() async throws {
        // Given
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let settings = MockSettingsManager()
        let cloud = MockCloudSyncManager()
        let userDefaults = try makeUserDefaults()
        cloud.cloudAvailable = false
        let item = MemoryItem(content: "Deleted")
        cloud.cloudMemoryItems = [item]
        let sut = MemoryManager(
            settingsManager: settings,
            cloudSyncManager: cloud,
            documentsURL: documentsURL,
            userDefaults: userDefaults
        )
        settings.isCloudSyncEnabled = true
        try await sut.add(item)
        cloud.syncError = CloudSyncError.containerUnavailable

        // When
        do {
            try await sut.delete(id: item.id)
            XCTFail("Expected cloud delete failure")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerUnavailable)
        }
        do {
            try await sut.synchronize()
            XCTFail("Expected retained deletion retry to fail")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, .containerUnavailable)
        }
        cloud.syncError = nil
        try await sut.synchronize()

        // Then
        XCTAssertFalse(sut.getItems().contains { $0.id == item.id })
        XCTAssertFalse(cloud.cloudMemoryItems?.contains { $0.id == item.id } ?? true)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("MemoryTombstones.json").path
        ))
    }

    func test_synchronize_equalRevisionConflict_selectsSameWinnerAndPreservesLoser() async throws {
        // Given
        let id = UUID()
        let revision = Date(timeIntervalSince1970: 1_000)
        let first = MemoryItem(id: id, content: "Alpha", createdAt: revision, updatedAt: revision)
        let second = MemoryItem(id: id, content: "Beta", createdAt: revision, updatedAt: revision)

        // When
        let firstResult = try await synchronize(local: first, cloud: second)
        let secondResult = try await synchronize(local: second, cloud: first)

        // Then
        XCTAssertEqual(firstResult.winner, secondResult.winner)
        XCTAssertEqual(firstResult.recovery, [firstResult.winner == first ? second : first])
        XCTAssertEqual(secondResult.recovery, [secondResult.winner == first ? second : first])
    }

    func test_synchronize_remoteDeletionIsNewer_removesStaleLocalItem() async throws {
        // Given
        let documentsURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settings = MockSettingsManager()
        let cloud = MockCloudSyncManager()
        let item = MemoryItem(content: "Stale", updatedAt: Date(timeIntervalSince1970: 1_000))
        let sut = MemoryManager(
            settingsManager: settings,
            cloudSyncManager: cloud,
            documentsURL: documentsURL,
            userDefaults: try makeUserDefaults()
        )
        try await sut.add(item)
        cloud.cloudMemoryDeletionMarkers = [
            CloudDeletionMarker(id: item.id, deletedAt: Date(timeIntervalSince1970: 2_000))
        ]
        settings.isCloudSyncEnabled = true

        // When
        try await sut.synchronize()

        // Then
        XCTAssertTrue(sut.getItems().isEmpty)
        XCTAssertEqual(cloud.cloudMemoryItems ?? [], [])
    }

    func test_add_sameIdAfterDeletion_createsNewerRevisionAndRetainsTombstone() async throws {
        // Given
        let documentsURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settings = MockSettingsManager()
        let cloud = MockCloudSyncManager()
        let original = MemoryItem(content: "Original")
        let sut = MemoryManager(
            settingsManager: settings,
            cloudSyncManager: cloud,
            documentsURL: documentsURL,
            userDefaults: try makeUserDefaults()
        )
        try await sut.add(original)
        try await sut.delete(id: original.id)

        // When
        let recreation = MemoryItem(
            id: original.id,
            content: "Recreated",
            createdAt: original.createdAt,
            updatedAt: .distantPast
        )
        try await sut.add(recreation)
        settings.isCloudSyncEnabled = true
        try await sut.synchronize()

        // Then
        let recreatedItem = try XCTUnwrap(sut.getItems().first)
        let marker = try XCTUnwrap(cloud.cloudMemoryDeletionMarkers.first)
        XCTAssertGreaterThan(recreatedItem.updatedAt, marker.deletedAt)
        XCTAssertEqual(cloud.cloudMemoryItems?.map(\.content), ["Recreated"])
        XCTAssertEqual(cloud.cloudMemoryDeletionMarkers.count, 1)
    }

    func test_migration_legacyItemWithoutUpdatedAt_verifiesWriteBeforeRemovingSource() async throws {
        // Given
        let documentsURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let defaults = try makeUserDefaults()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let legacy = LegacyMemoryItem(content: "Legacy", createdAt: createdAt)
        defaults.set(try legacyEncoder().encode([legacy]), forKey: "memory_items")
        let sut = MemoryManager(
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            documentsURL: documentsURL,
            userDefaults: defaults
        )

        // When
        try await sut.add(MemoryItem(content: "New"))

        // Then
        XCTAssertNil(defaults.data(forKey: "memory_items"))
        XCTAssertEqual(sut.getItems().first { $0.content == "Legacy" }?.updatedAt, createdAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent("Memory.json").path))
    }

    func test_migration_localWriteFails_throwsAndRetainsUserDefaultsSource() async throws {
        // Given
        let unavailableDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Missing")
        let defaults = try makeUserDefaults()
        let legacy = LegacyMemoryItem(content: "Legacy", createdAt: Date(timeIntervalSince1970: 1_000))
        defaults.set(try legacyEncoder().encode([legacy]), forKey: "memory_items")
        let sut = MemoryManager(
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            documentsURL: unavailableDirectory,
            userDefaults: defaults
        )

        // When
        do {
            try await sut.add(MemoryItem(content: "New"))
            XCTFail("Expected local write failure")
        } catch {
            // Then
            XCTAssertNotNil(defaults.data(forKey: "memory_items"))
        }
    }

    func test_add_localWriteFails_throwsFailure() async throws {
        // Given
        let unavailableDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Missing")
        let sut = MemoryManager(
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            documentsURL: unavailableDirectory,
            userDefaults: try makeUserDefaults()
        )

        // When
        do {
            try await sut.add(MemoryItem(content: "New"))
            XCTFail("Expected local write failure")
        } catch {
            // Then
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: unavailableDirectory.appendingPathComponent("Memory.json").path
            ))
        }
    }

    // MARK: - Private

    private func synchronize(local: MemoryItem, cloud: MemoryItem) async throws -> SyncResult {
        let documentsURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let settings = MockSettingsManager()
        let cloudManager = MockCloudSyncManager()
        let sut = MemoryManager(
            settingsManager: settings,
            cloudSyncManager: cloudManager,
            documentsURL: documentsURL,
            userDefaults: try makeUserDefaults()
        )
        try await sut.add(local)
        cloudManager.cloudMemoryItems = [cloud]
        settings.isCloudSyncEnabled = true
        try await sut.synchronize()
        let recoveryData = try Data(contentsOf: documentsURL.appendingPathComponent("MemoryRecovery.json"))
        let recovery = try SyncJSONCoding.makeDecoder().decode([MemoryItem].self, from: recoveryData)
        return SyncResult(winner: try XCTUnwrap(sut.getItems().first), recovery: recovery)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "MemoryManagerCloudDeletionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { throw CocoaError(.fileWriteUnknown) }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func legacyEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private struct SyncResult {
    let winner: MemoryItem
    let recovery: [MemoryItem]
}

private struct LegacyMemoryItem: Codable {
    let id = UUID()
    let content: String
    let isEnabled = true
    let createdAt: Date
    let source = MemoryItem.Source.user
}
