//
//  EnableCloudSyncUseCaseTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class EnableCloudSyncUseCaseTests: XCTestCase {
    func test_execute_availableCloud_readsEveryCategoryWithoutWriting() async throws {
        // Given
        let cloud = MockCloudSyncManager()
        let profile = MockUserProfileManager()
        let sut = makeSUT(cloud: cloud, profile: profile)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result, .ready)
        XCTAssertEqual(cloud.loadConversationsCallCount, 1)
        XCTAssertEqual(cloud.loadProfileCallCount, 1)
        XCTAssertEqual(cloud.loadMemoryCallCount, 1)
        XCTAssertEqual(cloud.loadTemplatesCallCount, 1)
        XCTAssertEqual(cloud.applyProfileCallCount, 0)
        XCTAssertTrue(cloud.syncedConversations.isEmpty)
        XCTAssertTrue(cloud.syncedTemplates.isEmpty)
        XCTAssertNil(cloud.savedMemoryItems)
    }

    func test_execute_equalRevisionDivergentProfiles_returnsProfileConflict() async throws {
        // Given
        let revision = Date(timeIntervalSince1970: 100)
        let cloud = MockCloudSyncManager()
        cloud.cloudProfile = UserProfile(name: "Cloud", modifiedAt: revision)
        let profile = MockUserProfileManager()
        profile.localProfileState = .profile(UserProfile(name: "Local", modifiedAt: revision))
        let sut = makeSUT(cloud: cloud, profile: profile)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result, .profileConflict)
    }

    func test_execute_newerDivergentProfile_returnsReadyForAutomaticResolution() async throws {
        // Given
        let cloud = MockCloudSyncManager()
        cloud.cloudProfile = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        let profile = MockUserProfileManager()
        profile.localProfileState = .profile(UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100)))
        let sut = makeSUT(cloud: cloud, profile: profile)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result, .ready)
    }

    func test_execute_missingIdentity_throwsAccountUnavailableBeforeMetadataReads() async {
        // Given
        let cloud = MockCloudSyncManager()
        let sut = EnableCloudSyncUseCase(
            cloudSyncManager: cloud,
            userProfileManager: MockUserProfileManager(),
            hasUbiquityIdentity: { false }
        )

        // When / Then
        do {
            _ = try await sut.execute()
            XCTFail("Expected account unavailable")
        } catch {
            XCTAssertEqual(error as? CloudSyncPreflightError, .accountUnavailable)
            XCTAssertEqual(cloud.loadConversationsCallCount, 0)
        }
    }

    func test_execute_mixedCategoryProblems_readsAllCategoriesAndReturnsEveryIssue() async {
        // Given
        let cloud = MockCloudSyncManager()
        cloud.conversationLoadError = CloudSyncError.requiredDownloadPending
        cloud.profileLoadError = CloudSyncError.containerUnavailable
        cloud.memoryLoadError = CloudSyncError.invalidProfileData
        let sut = makeSUT(cloud: cloud, profile: MockUserProfileManager())

        // When / Then
        do {
            _ = try await sut.execute()
            XCTFail("Expected composite preflight issues")
        } catch CloudSyncPreflightError.issues(let issues) {
            XCTAssertEqual(issues.pendingCategories, [.conversations, .attachments])
            XCTAssertEqual(issues.unavailableCategories, [.profile: .containerUnavailable])
            XCTAssertEqual(issues.failureReasons, [.memory: .invalidData])
            XCTAssertEqual(cloud.loadTemplatesCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSUT(
        cloud: MockCloudSyncManager,
        profile: MockUserProfileManager
    ) -> EnableCloudSyncUseCase {
        EnableCloudSyncUseCase(
            cloudSyncManager: cloud,
            userProfileManager: profile,
            hasUbiquityIdentity: { true }
        )
    }
}
