//
//  CloudDataManagementUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudDataManagementUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var cloud: MockCloudSyncManager!
    private var conversations: MockConversationRepository!
    private var profile: MockUserProfileManager!
    private var memory: MockMemoryManager!
    private var templates: MockPromptTemplateRepository!
    private var settings: MockSettingsManager!
    private var sut: CloudDataManagementUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        cloud = MockCloudSyncManager()
        conversations = MockConversationRepository()
        profile = MockUserProfileManager()
        memory = MockMemoryManager()
        templates = MockPromptTemplateRepository()
        settings = MockSettingsManager()
        settings.isCloudSyncEnabled = true
        sut = CloudDataManagementUseCase(
            cloudSyncManager: cloud,
            conversationRepository: conversations,
            userProfileManager: profile,
            memoryManager: memory,
            promptTemplateRepository: templates,
            settingsManager: settings,
            mutationGate: CloudSynchronizationMutationGate()
        )
    }

    override func tearDown() async throws {
        sut = nil
        templates = nil
        settings = nil
        memory = nil
        profile = nil
        conversations = nil
        cloud = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_deleteAll_categoryFailure_returnsExactOutcomesAndKeepsFailedLocalData() async throws {
        // Given
        memory.items = [MemoryItem(content: "Keep")]
        templates.templates = [PromptTemplate(title: "Delete", content: "Body")]
        cloud.deletionOutcomes[.memory] = .failed(.fileAccess)

        // When
        let result = try await sut.deleteAll()

        // Then
        XCTAssertEqual(result.outcomes[.memory], .failed(.fileAccess))
        XCTAssertFalse(memory.deleteLocalDataCalled)
        XCTAssertTrue(templates.deleteAllLocalCalled)
    }

    func test_retryDeletion_partialFailure_reusesMarkerAndRetriesOnlyFailure() async throws {
        // Given
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: Date())
        let initial = CloudDeletionResult(
            marker: marker,
            outcomes: [
                .conversations: .deleted,
                .profile: .deleted,
                .memory: .failed(.fileAccess),
                .promptTemplates: .deleted
            ]
        )
        cloud.purgeMarker = marker

        // When
        let result = try await sut.retryDeletion(initial)

        // Then
        XCTAssertEqual(result.marker, marker)
        XCTAssertEqual(result.outcomes[.memory], .deleted)
        XCTAssertTrue(memory.deleteLocalDataCalled)
        XCTAssertEqual(conversations.purgeLocalDataCallCount, 0)
    }

    func test_resumeDeletion_markerOnlyCompletion_retriesEveryCategory() async throws {
        // Given
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: Date())
        cloud.purgeMarker = marker

        // When
        let result = try await sut.resumeDeletion()

        // Then
        XCTAssertEqual(result?.marker, marker)
        XCTAssertEqual(result?.failedCategories, [])
        XCTAssertEqual(conversations.purgeLocalDataCallCount, 1)
        XCTAssertTrue(profile.localProfile.isEmpty)
        XCTAssertTrue(memory.deleteLocalDataCalled)
        XCTAssertTrue(templates.deleteAllLocalCalled)
    }

    func test_deleteProfile_forwardsDurableProfileDeletion() async throws {
        // Given

        // When
        try await sut.deleteProfile()

        // Then
        XCTAssertTrue(profile.deleteProfileCalled)
    }

    func test_deleteMemory_repeatedDelete_remainsIdempotentAtDomainBoundary() async throws {
        // Given
        let id = UUID()

        // When
        try await sut.deleteMemory(id: id)
        try await sut.deleteMemory(id: id)

        // Then
        XCTAssertEqual(memory.deletedId, id)
        XCTAssertTrue(memory.items.isEmpty)
    }

    func test_deleteConversation_cloudSyncDisabled_rejectsWithoutLocalDeletion() async {
        // Given
        let id = UUID()
        settings.isCloudSyncEnabled = false

        // When
        do {
            try await sut.deleteConversation(id: id)
            XCTFail("Expected disabled synchronization rejection")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudDataManagementError, .cloudSyncDisabled)
            XCTAssertTrue(conversations.deletedIds.isEmpty)
        }
    }

    func test_retryDeletion_localFailure_preservesRecordCreatedAfterMarker() async throws {
        // Given
        memory.mutationError = CocoaError(.fileWriteUnknown)
        let first = try await sut.deleteAll()
        let recreated = MemoryItem(
            content: "Recreated",
            updatedAt: first.marker.deletedAt.addingTimeInterval(1)
        )
        memory.items = [recreated]
        memory.mutationError = nil

        // When
        let retried = try await sut.retryDeletion(first)

        // Then
        XCTAssertEqual(retried.outcomes[.memory], .deleted)
        XCTAssertEqual(memory.items, [recreated])
        XCTAssertEqual(cloud.requestedDeletionCategories.last, [.memory])
    }

    func test_resumeDeletion_completedCategories_retriesOnlyUnfinishedCategories() async throws {
        // Given
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: Date())
        cloud.purgeMarker = marker
        cloud.purgeJournal = CloudPurgeJournal(
            marker: marker,
            categoryStates: [
                .conversations: .completed,
                .profile: .completed,
                .memory: .cloudCleanupCompleted,
                .promptTemplates: .completed
            ]
        )

        // When
        let result = try await sut.resumeDeletion()

        // Then
        XCTAssertEqual(cloud.requestedDeletionCategories, [[.memory]])
        XCTAssertEqual(result?.failedCategories, [])
        XCTAssertEqual(result?.outcomes[.conversations], .deleted)
        XCTAssertEqual(result?.outcomes[.profile], .deleted)
        XCTAssertEqual(result?.outcomes[.memory], .deleted)
        XCTAssertEqual(result?.outcomes[.promptTemplates], .deleted)
        XCTAssertEqual(conversations.purgeLocalDataCallCount, 0)
        XCTAssertTrue(memory.deleteLocalDataCalled)
    }

    func test_resumeDeletion_completedJournal_returnsNoOperation() async throws {
        // Given
        let marker = CloudPurgeMarker(id: UUID(), deletedAt: Date())
        cloud.purgeMarker = marker
        cloud.purgeJournal = CloudPurgeJournal(
            marker: marker,
            categoryStates: Dictionary(uniqueKeysWithValues: CloudDataCategory.allCases.map { ($0, .completed) })
        )

        // When
        let result = try await sut.resumeDeletion()

        // Then
        XCTAssertNil(result)
        XCTAssertTrue(cloud.requestedDeletionCategories.isEmpty)
    }
}
