//
//  MemoryManagerReconciliationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MemoryManagerReconciliationTests: XCTestCase {
    // MARK: - Tests

    func test_synchronize_localOnly_preservesItemLocallyAndUploadsToCloud() async throws {
        try await withHarness { harness in
            // Given
            let item = MemoryItem(content: "Local", createdAt: revision(1_000))
            try await harness.manager.add(item)
            harness.settings.isCloudSyncEnabled = true

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertEqual(harness.manager.getItems(), [item])
            XCTAssertEqual(harness.cloud.cloudMemoryItems, [item])
        }
    }

    func test_synchronize_cloudOnly_downloadsItemAndPreservesCloud() async throws {
        try await withHarness { harness in
            // Given
            let item = MemoryItem(content: "Cloud", createdAt: revision(1_000))
            harness.cloud.cloudMemoryItems = [item]
            harness.settings.isCloudSyncEnabled = true

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertEqual(harness.manager.getItems(), [item])
            XCTAssertEqual(harness.cloud.cloudMemoryItems, [item])
        }
    }

    func test_synchronize_newerLocal_selectsLocalAndRecoversCloud() async throws {
        try await withHarness { harness in
            // Given
            let id = UUID()
            let cloudItem = makeItem(id: id, content: "Cloud", updatedAt: revision(1_000))
            let localItem = makeItem(id: id, content: "Local", updatedAt: revision(2_000))
            try await harness.manager.add(localItem)
            harness.cloud.cloudMemoryItems = [cloudItem]
            harness.settings.isCloudSyncEnabled = true

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertEqual(harness.manager.getItems(), [localItem])
            XCTAssertEqual(try harness.recoveryItems(), [cloudItem])
        }
    }

    func test_synchronize_newerCloud_selectsCloudAndRecoversLocal() async throws {
        try await withHarness { harness in
            // Given
            let id = UUID()
            let localItem = makeItem(id: id, content: "Local", updatedAt: revision(1_000))
            let cloudItem = makeItem(id: id, content: "Cloud", updatedAt: revision(2_000))
            try await harness.manager.add(localItem)
            harness.cloud.cloudMemoryItems = [cloudItem]
            harness.settings.isCloudSyncEnabled = true

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertEqual(harness.manager.getItems(), [cloudItem])
            XCTAssertEqual(try harness.recoveryItems(), [localItem])
        }
    }

    func test_synchronize_equalDivergent_selectsDeterministicWinnerForEitherInputOrder() async throws {
        // Given
        let id = UUID()
        let first = makeItem(id: id, content: "Alpha", updatedAt: revision(1_000))
        let second = makeItem(id: id, content: "Beta", updatedAt: revision(1_000))

        // When
        let localFirst = try await reconciliationResult(local: first, cloud: second)
        let cloudFirst = try await reconciliationResult(local: second, cloud: first)

        // Then
        XCTAssertEqual(localFirst.winner, cloudFirst.winner)
        XCTAssertEqual(localFirst.recovery, [localFirst.winner == first ? second : first])
        XCTAssertEqual(cloudFirst.recovery, localFirst.recovery)
    }

    func test_synchronize_tombstoneRejectsLocal_recoversItemBeforeRemoval() async throws {
        try await withHarness { harness in
            // Given
            let item = makeItem(id: UUID(), content: "Stale", updatedAt: revision(1_000))
            try await harness.manager.add(item)
            harness.cloud.cloudMemoryDeletionMarkers = [
                CloudDeletionMarker(id: item.id, deletedAt: revision(2_000))
            ]
            harness.settings.isCloudSyncEnabled = true

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertTrue(harness.manager.getItems().isEmpty)
            XCTAssertEqual(try harness.recoveryItems(), [item])
        }
    }

    func test_synchronize_repeatedUnchangedInput_preservesLocalBytesAndModificationDates() async throws {
        try await withHarness { harness in
            // Given
            let id = UUID()
            let localItem = makeItem(id: id, content: "Local", updatedAt: revision(1_000))
            let cloudItem = makeItem(id: id, content: "Cloud", updatedAt: revision(2_000))
            try await harness.manager.add(localItem)
            harness.cloud.cloudMemoryItems = [cloudItem]
            harness.settings.isCloudSyncEnabled = true
            try await harness.manager.synchronize()
            let urls = harness.persistedURLs
            let originalData = try urls.map { try Data(contentsOf: $0) }
            let sentinelDate = revision(100)
            for url in urls {
                try FileManager.default.setAttributes([.modificationDate: sentinelDate], ofItemAtPath: url.path)
            }

            // When
            try await harness.manager.synchronize()

            // Then
            XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originalData)
            for url in urls {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                XCTAssertEqual(attributes[.modificationDate] as? Date, sentinelDate)
            }
        }
    }

    // MARK: - Private

    private func reconciliationResult(local: MemoryItem, cloud: MemoryItem) async throws -> ReconciliationResult {
        try await withHarness { harness in
            try await harness.manager.add(local)
            harness.cloud.cloudMemoryItems = [cloud]
            harness.settings.isCloudSyncEnabled = true
            try await harness.manager.synchronize()
            return ReconciliationResult(
                winner: try XCTUnwrap(harness.manager.getItems().first),
                recovery: try harness.recoveryItems()
            )
        }
    }

    private func withHarness<Result>(
        _ operation: @MainActor (ReconciliationHarness) async throws -> Result
    ) async throws -> Result {
        let documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documentsURL) }
        let suiteName = "MemoryManagerReconciliationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { throw CocoaError(.fileWriteUnknown) }
        defaults.removePersistentDomain(forName: suiteName)
        let settings = MockSettingsManager()
        let cloud = MockCloudSyncManager()
        let manager = MemoryManager(
            settingsManager: settings,
            cloudSyncManager: cloud,
            documentsURL: documentsURL,
            userDefaults: defaults
        )
        return try await operation(ReconciliationHarness(
            documentsURL: documentsURL,
            settings: settings,
            cloud: cloud,
            manager: manager
        ))
    }

    private func makeItem(id: UUID, content: String, updatedAt: Date) -> MemoryItem {
        MemoryItem(id: id, content: content, createdAt: revision(500), updatedAt: updatedAt)
    }

    private func revision(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}

private struct ReconciliationHarness {
    let documentsURL: URL
    let settings: MockSettingsManager
    let cloud: MockCloudSyncManager
    let manager: MemoryManager

    var persistedURLs: [URL] {
        ["Memory.json", "MemoryRecovery.json", "MemoryTombstones.json"].map {
            documentsURL.appendingPathComponent($0)
        }
    }

    func recoveryItems() throws -> [MemoryItem] {
        let data = try Data(contentsOf: documentsURL.appendingPathComponent("MemoryRecovery.json"))
        return try SyncJSONCoding.makeDecoder().decode([MemoryItem].self, from: data)
    }
}

private struct ReconciliationResult {
    let winner: MemoryItem
    let recovery: [MemoryItem]
}
