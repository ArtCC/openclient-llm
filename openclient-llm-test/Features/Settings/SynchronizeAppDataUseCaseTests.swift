//
//  SynchronizeAppDataUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SynchronizeAppDataUseCaseTests: XCTestCase {
    // MARK: - Tests

    func test_execute_allCategoriesSucceed_returnsSuccessfulResult() async {
        // Given
        let dependencies = makeDependencies()
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(dependencies.conversations.executeCallCount, 1)
        XCTAssertEqual(dependencies.profile.getCloudProfileCallCount, 1)
        XCTAssertTrue(dependencies.memory.synchronizeCalled)
        XCTAssertEqual(dependencies.templates.loadCallCount, 1)
    }

    func test_execute_categoryFailures_returnsEveryAffectedCategory() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.conversations.result = .synchronized
        dependencies.memory.synchronizeError = CloudSyncError.requiredDownloadPending
        dependencies.templates.loadError = NSError(domain: "SynchronizeAppDataUseCaseTests", code: 1)
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.categories(with: .pendingDownload), [.memory])
        XCTAssertEqual(result.categories(with: .failed), [.promptTemplates])
        XCTAssertEqual(dependencies.templates.loadCallCount, 1)
        XCTAssertFalse(result.isSuccessful)
    }

    func test_execute_divergentProfile_returnsConflictWithoutSkippingLaterCategories() async {
        // Given
        let dependencies = makeDependencies()
        let modifiedAt = Date()
        dependencies.profile.localProfile = UserProfile(
            name: "Local",
            profileDescription: "",
            extraInfo: "",
            modifiedAt: modifiedAt
        )
        dependencies.profile.cloudProfile = UserProfile(
            name: "Cloud",
            profileDescription: "",
            extraInfo: "",
            modifiedAt: modifiedAt
        )
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.categories(with: .conflict), [.profile])
        XCTAssertTrue(dependencies.memory.synchronizeCalled)
        XCTAssertEqual(dependencies.templates.loadCallCount, 1)
    }
}

// MARK: - Helpers

private extension SynchronizeAppDataUseCaseTests {
    struct Dependencies {
        let conversations: MockSyncConversationsUseCase
        let profile: MockUserProfileManager
        let memory: MockMemoryManager
        let templates: MockPromptTemplateRepository
    }

    func makeDependencies() -> Dependencies {
        Dependencies(
            conversations: MockSyncConversationsUseCase(),
            profile: MockUserProfileManager(),
            memory: MockMemoryManager(),
            templates: MockPromptTemplateRepository()
        )
    }

    func makeSUT(_ dependencies: Dependencies) -> SynchronizeAppDataUseCase {
        SynchronizeAppDataUseCase(
            syncConversationsUseCase: dependencies.conversations,
            userProfileManager: dependencies.profile,
            memoryManager: dependencies.memory,
            promptTemplateRepository: dependencies.templates
        )
    }
}
