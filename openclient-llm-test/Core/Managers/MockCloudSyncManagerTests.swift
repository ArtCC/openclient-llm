//
//  MockCloudSyncManagerTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MockCloudSyncManagerTests: XCTestCase {
    // MARK: - Tests

    func test_categorySnapshots_cloudUnavailable_throwContainerUnavailable() async {
        // Given
        let sut = MockCloudSyncManager()
        sut.cloudAvailable = false

        // When / Then
        assertCloudError { _ = try sut.loadConversationSyncSnapshot() }
        await assertCloudError { _ = try await sut.loadProfileSyncSnapshot() }
        await assertCloudError { _ = try await sut.loadTemplatesFromCloud() }
        await assertCloudError { _ = try await sut.loadMemorySyncSnapshot() }
    }

    func test_categoryApplyAndDelete_cloudUnavailable_throwContainerUnavailable() async throws {
        // Given
        let sut = MockCloudSyncManager()
        let conversations = try sut.loadConversationSyncSnapshot()
        let profile = try await sut.loadProfileSyncSnapshot()
        let templates = try await sut.loadTemplatesFromCloud()
        let memory = try await sut.loadMemorySyncSnapshot()
        sut.cloudAvailable = false
        let conversationOutput = ConversationCloudSyncOutput(
            conversations: [],
            conversationData: [:],
            tombstones: [],
            deleteAllMarker: nil,
            attachments: [:]
        )

        // When / Then
        assertCloudError { try sut.applyConversationSyncOutput(conversationOutput, basedOn: conversations) }
        assertCloudError { try sut.validateConversationSyncOutput(conversationOutput, basedOn: conversations) }
        assertCloudError { try sut.deleteConversationFromCloud(UUID()) }
        assertCloudError { try sut.deleteAllFromCloud() }
        await assertCloudError { try await sut.applyProfileSyncOutput(.unchanged, basedOn: profile) }
        await assertCloudError { try await sut.applyTemplateUploads([], basedOn: templates) }
        await assertCloudError {
            try await sut.applyTemplateDeletion(CloudDeletionMarker(id: UUID(), deletedAt: Date()), basedOn: templates)
        }
        await assertCloudError {
            try await sut.applyMemorySyncOutput(items: [], deletionMarkers: [], basedOn: memory)
        }
        await assertCloudError { try await sut.deleteMemoryItemFromCloud(UUID(), deletedAt: Date()) }
    }

    func test_categoryOperations_injectedErrors_takePrecedenceOverUnavailableContainer() async throws {
        // Given
        let sut = MockCloudSyncManager()
        let profile = try await sut.loadProfileSyncSnapshot()
        sut.cloudAvailable = false
        sut.loadError = CloudSyncError.requiredDownloadPending

        // When / Then
        await assertCloudError(.requiredDownloadPending) { _ = try await sut.loadProfileSyncSnapshot() }
        sut.loadError = nil
        sut.syncError = CloudSyncError.cloudContentChanged
        await assertCloudError(.cloudContentChanged) {
            try await sut.applyProfileSyncOutput(.unchanged, basedOn: profile)
        }
    }
}

// MARK: - Private

private extension MockCloudSyncManagerTests {
    func assertCloudError(
        _ expected: CloudSyncError = .containerUnavailable,
        operation: () throws -> Void
    ) {
        XCTAssertThrowsError(try operation()) { error in
            XCTAssertEqual(error as? CloudSyncError, expected)
        }
    }

    func assertCloudError(
        _ expected: CloudSyncError = .containerUnavailable,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected cloud error")
        } catch {
            XCTAssertEqual(error as? CloudSyncError, expected)
        }
    }
}
