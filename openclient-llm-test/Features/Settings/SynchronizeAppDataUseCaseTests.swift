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
        XCTAssertNotNil(dependencies.settings.lastSuccessfulCloudSyncDate)
        XCTAssertEqual(dependencies.runtimeStore.status, .synchronized(
            lastSuccessfulSyncAt: dependencies.settings.lastSuccessfulCloudSyncDate ?? .distantPast
        ))
    }

    func test_execute_preflightChecking_doesNotWriteAnyCategory() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.runtimeStore.publish(.checkingAvailability)
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertTrue(result.isCancelled)
        XCTAssertEqual(dependencies.conversations.executeCallCount, 0)
        XCTAssertEqual(dependencies.profile.getCloudProfileCallCount, 0)
        XCTAssertFalse(dependencies.memory.synchronizeCalled)
        XCTAssertEqual(dependencies.templates.loadCallCount, 0)
    }

    func test_execute_accountChanged_blocksEveryCategoryWithoutMutation() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.accountAssociation.associationState = .changed
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.categories(with: .failed), Set(AppSynchronizationResult.Category.allCases))
        XCTAssertEqual(Set(result.failureReasons.values), [.accountChanged])
        XCTAssertEqual(dependencies.conversations.executeCallCount, 0)
        XCTAssertEqual(dependencies.profile.getCloudProfileCallCount, 0)
        XCTAssertFalse(dependencies.memory.synchronizeCalled)
        XCTAssertEqual(dependencies.templates.loadCallCount, 0)
        XCTAssertEqual(dependencies.runtimeStore.status, .failed(.init(
            reason: .accountChanged,
            affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
        )))
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
        XCTAssertNil(dependencies.settings.lastSuccessfulCloudSyncDate)
        XCTAssertEqual(dependencies.runtimeStore.status, .incomplete(.init(
            pendingCategories: [.memory],
            unavailableCategories: [:],
            failureReasons: [.promptTemplates: .other]
        )))
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

    func test_execute_validEmptyLocalProfileWithMissingCloud_uploadsProfile() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.profile.localProfileState = .profile(
            UserProfile(modifiedAt: Date(timeIntervalSince1970: 100))
        )
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.outcomes[.profile], .synchronized)
        XCTAssertEqual(dependencies.profile.resolvedKeepLocal, true)
    }

    func test_execute_missingLocalProfileWithValidEmptyCloud_downloadsProfile() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.profile.cloudProfile = UserProfile(modifiedAt: Date(timeIntervalSince1970: 100))
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.outcomes[.profile], .synchronized)
        XCTAssertEqual(dependencies.profile.resolvedKeepLocal, false)
    }

    func test_execute_invalidLocalProfile_reportsProfileFailureWithoutResolving() async {
        // Given
        let dependencies = makeDependencies()
        dependencies.profile.localProfileError = CloudSyncError.invalidProfileData
        let sut = makeSUT(dependencies)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.outcomes[.profile], .failed)
        XCTAssertEqual(result.failureReasons[.profile], .invalidData)
        XCTAssertNil(dependencies.profile.resolvedKeepLocal)
        XCTAssertEqual(dependencies.runtimeStore.status, .incomplete(.init(
            pendingCategories: [],
            unavailableCategories: [:],
            failureReasons: [.profile: .invalidData]
        )))
    }

    func test_cancel_activeSynchronization_cancelsGateAndConversationSynchronization() async {
        // Given
        let dependencies = makeDependencies()
        let gate = FullAppSynchronizationGate()
        let sut = makeSUT(dependencies, synchronizationGate: gate)
        let blocker = SynchronizationBlocker()
        dependencies.conversations.executeHandler = {
            await blocker.waitUntilCancelled()
            return .failed
        }
        let request = Task { await sut.execute() }
        await blocker.waitUntilEntered()

        // When
        await sut.cancel()
        let result = await request.value
        await blocker.waitForCancellation()
        let observedCancellation = await blocker.observedCancellation
        let pendingRequestCount = await gate.pendingRequestCount

        // Then
        XCTAssertEqual(dependencies.conversations.cancelCallCount, 1)
        XCTAssertTrue(result.isCancelled)
        XCTAssertTrue(observedCancellation)
        XCTAssertEqual(pendingRequestCount, 0)
        XCTAssertEqual(dependencies.profile.getCloudProfileCallCount, 0)
        XCTAssertFalse(dependencies.memory.synchronizeCalled)
        XCTAssertEqual(dependencies.templates.loadCallCount, 0)
    }

    func test_execute_fullSyncAndStandaloneMutation_cannotOverlap() async throws {
        // Given
        let dependencies = makeDependencies()
        let mutationGate = CloudSynchronizationMutationGate()
        let blocker = SynchronizationReleaseBlocker()
        dependencies.conversations.executeHandler = {
            await blocker.waitForRelease()
            return .synchronized
        }
        let sut = makeSUT(dependencies, mutationGate: mutationGate)
        let fullSync = Task { await sut.execute() }
        await blocker.waitUntilEntered()
        let standalone = Task {
            try await mutationGate.perform { await blocker.recordStandaloneEntry() }
        }
        while await mutationGate.pendingRequestCount < 1 { await Task.yield() }

        // When
        let didStandaloneEnterDuringFullSync = await blocker.didStandaloneEnter
        await blocker.release()
        _ = await fullSync.value
        try await standalone.value
        let didStandaloneEnterAfterFullSync = await blocker.didStandaloneEnter

        // Then
        XCTAssertFalse(didStandaloneEnterDuringFullSync)
        XCTAssertTrue(didStandaloneEnterAfterFullSync)
    }

    func test_execute_nestedCategoryMutationGateAcquisition_doesNotDeadlock() async {
        // Given
        let dependencies = makeDependencies()
        let mutationGate = CloudSynchronizationMutationGate()
        dependencies.conversations.executeHandler = {
            do {
                return try await mutationGate.perform { .synchronized }
            } catch {
                return .failed
            }
        }
        let sut = makeSUT(dependencies, mutationGate: mutationGate)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertTrue(result.isSuccessful)
    }

    func test_execute_coalescedFollowUp_keepsSynchronizingUntilBatchDrains() async {
        // Given
        let dependencies = makeDependencies()
        let gate = FullAppSynchronizationGate()
        let sequence = SynchronizationSequenceGate()
        dependencies.conversations.executeHandler = { await sequence.execute() }
        let sut = makeSUT(dependencies, synchronizationGate: gate)
        let first = Task { await sut.execute() }
        await sequence.waitForExecutionCount(1)
        let second = Task { await sut.execute() }
        while await gate.pendingRequestCount < 1 { await Task.yield() }

        // When
        await sequence.resumeNext()
        await sequence.waitForExecutionCount(2)

        // Then
        XCTAssertEqual(dependencies.runtimeStore.status, .synchronizing)
        XCTAssertNil(dependencies.settings.lastSuccessfulCloudSyncDate)
        await sequence.resumeNext()
        _ = await first.value
        _ = await second.value
        XCTAssertNotNil(dependencies.settings.lastSuccessfulCloudSyncDate)
    }
}

// MARK: - Helpers

private extension SynchronizeAppDataUseCaseTests {
    struct Dependencies {
        let conversations: MockSyncConversationsUseCase
        let profile: MockUserProfileManager
        let memory: MockMemoryManager
        let templates: MockPromptTemplateRepository
        let settings: MockSettingsManager
        let runtimeStore: CloudSyncRuntimeStore
        let accountAssociation: MockCloudAccountAssociation
    }

    func makeDependencies() -> Dependencies {
        let settings = MockSettingsManager()
        settings.isCloudSyncEnabled = true
        return Dependencies(
            conversations: MockSyncConversationsUseCase(),
            profile: MockUserProfileManager(),
            memory: MockMemoryManager(),
            templates: MockPromptTemplateRepository(),
            settings: settings,
            runtimeStore: CloudSyncRuntimeStore(
                status: .idle(lastSuccessfulSyncAt: nil),
                isPreflightComplete: true
            ),
            accountAssociation: MockCloudAccountAssociation()
        )
    }

    func makeSUT(
        _ dependencies: Dependencies,
        synchronizationGate: FullAppSynchronizationGate = FullAppSynchronizationGate(),
        mutationGate: CloudSynchronizationMutationGate = CloudSynchronizationMutationGate()
    ) -> SynchronizeAppDataUseCase {
        SynchronizeAppDataUseCase(
            syncConversationsUseCase: dependencies.conversations,
            userProfileManager: dependencies.profile,
            memoryManager: dependencies.memory,
            promptTemplateRepository: dependencies.templates,
            settingsManager: dependencies.settings,
            synchronizationGate: synchronizationGate,
            mutationGate: mutationGate,
            runtimeStore: dependencies.runtimeStore,
            accountAssociation: dependencies.accountAssociation
        )
    }
}

private actor SynchronizationReleaseBlocker {
    private var isEntered = false
    private var isReleased = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var didStandaloneEnter = false

    func waitForRelease() async {
        isEntered = true
        for waiter in enteredWaiters { waiter.resume() }
        enteredWaiters = []
        guard !isReleased else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !isEntered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func recordStandaloneEntry() {
        didStandaloneEnter = true
    }

    func release() {
        isReleased = true
        for waiter in releaseWaiters { waiter.resume() }
        releaseWaiters = []
    }
}

private actor SynchronizationBlocker {
    private var entered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var observedCancellation = false

    func waitUntilCancelled() async {
        entered = true
        for waiter in enteredWaiters { waiter.resume() }
        enteredWaiters = []
        while !Task.isCancelled {
            await Task.yield()
        }
        observedCancellation = true
        for waiter in cancellationWaiters { waiter.resume() }
        cancellationWaiters = []
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func waitForCancellation() async {
        guard !observedCancellation else { return }
        await withCheckedContinuation { cancellationWaiters.append($0) }
    }
}

private actor SynchronizationSequenceGate {
    private var executionCount = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func execute() async -> ConversationSyncResult {
        executionCount += 1
        let satisfied = countWaiters.filter { executionCount >= $0.0 }
        countWaiters.removeAll { executionCount >= $0.0 }
        for waiter in satisfied { waiter.1.resume() }
        await withCheckedContinuation { continuations.append($0) }
        return .synchronized
    }

    func waitForExecutionCount(_ count: Int) async {
        guard executionCount < count else { return }
        await withCheckedContinuation { countWaiters.append((count, $0)) }
    }

    func resumeNext() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }
}
