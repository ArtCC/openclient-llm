//
//  ConversationSyncCoordinatorTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationSyncCoordinatorTests: XCTestCase {
    func test_synchronize_concurrentRequests_runsOneCurrentAndOneFollowUp() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let firstRunStarted = expectation(description: "First synchronization started")
        let releaseFirstRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            guard cloudManager.loadConversationsCallCount == 1 else { return }
            firstRunStarted.fulfill()
            releaseFirstRun.wait()
        }
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        let sut = ConversationSyncCoordinator(storage: storage)

        // When
        let first = Task { await sut.synchronize() }
        await fulfillment(of: [firstRunStarted], timeout: 2)
        let second = Task { await sut.synchronize() }
        let third = Task { await sut.synchronize() }
        for _ in 0..<10 { await Task.yield() }
        releaseFirstRun.signal()
        let firstResult = await first.value
        let secondResult = await second.value
        let thirdResult = await third.value

        // Then
        XCTAssertEqual([firstResult, secondResult, thirdResult], [.synchronized, .synchronized, .synchronized])
        XCTAssertEqual(cloudManager.loadConversationsCallCount, 2)
    }

    func test_cancel_activeSynchronization_resumesWaiterWithoutWriting() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let firstRunStarted = expectation(description: "Synchronization started")
        let releaseFirstRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            firstRunStarted.fulfill()
            releaseFirstRun.wait()
        }
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        let sut = ConversationSyncCoordinator(storage: storage)
        let synchronization = Task { await sut.synchronize() }
        await fulfillment(of: [firstRunStarted], timeout: 2)

        // When
        let cancellation = Task { await sut.cancel() }
        for _ in 0..<10 { await Task.yield() }
        releaseFirstRun.signal()
        await cancellation.value
        let result = await synchronization.value
        _ = try await storage.loadLocal()

        // Then
        XCTAssertEqual(result, .unavailable)
        XCTAssertTrue(cloudManager.syncedConversations.isEmpty)
    }

    func test_cancel_mutationQueuedBehindSynchronization_preventsMutation() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let conversation = Conversation(title: "Original", modelId: "model")
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        try await storage.save(conversation)
        let runStarted = expectation(description: "Synchronization started")
        let releaseRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            runStarted.fulfill()
            releaseRun.wait()
        }
        let sut = ConversationSyncCoordinator(storage: storage)
        let synchronization = Task { await sut.synchronize() }
        await fulfillment(of: [runStarted], timeout: 2)
        let admissionToken = await sut.admissionToken()
        let mutation = Task {
            try await sut.rename(
                conversation.id,
                title: "Renamed",
                synchronize: true,
                admissionToken: admissionToken
            )
        }

        // When
        let cancellation = Task { await sut.cancel() }
        for _ in 0..<10 { await Task.yield() }
        releaseRun.signal()
        await cancellation.value
        _ = await synchronization.value

        // Then
        do {
            _ = try await mutation.value
            XCTFail("Expected mutation cancellation")
        } catch is CancellationError {
            let localConversation = try await storage.loadLocal().first
            XCTAssertEqual(localConversation?.title, "Original")
        }
    }

    func test_cancel_saveQueuedBehindSynchronization_persistsUserContentLocally() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let base = Conversation(modelId: "model")
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        try await storage.save(base)
        let runStarted = expectation(description: "Synchronization started")
        let releaseRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            runStarted.fulfill()
            releaseRun.wait()
        }
        let sut = ConversationSyncCoordinator(storage: storage)
        let synchronization = Task { await sut.synchronize() }
        await fulfillment(of: [runStarted], timeout: 2)
        let admissionToken = await sut.admissionToken()
        var updated = base
        updated.messages.append(ChatMessage(role: .user, content: "Keep me"))
        updated.updatedAt = Date()
        let save = Task {
            try await sut.save(
                updated,
                expectedBase: base,
                synchronize: true,
                admissionToken: admissionToken
            )
        }

        // When
        let cancellation = Task { await sut.cancel() }
        for _ in 0..<10 { await Task.yield() }
        releaseRun.signal()
        await cancellation.value
        _ = await synchronization.value
        _ = try await save.value

        // Then
        let local = try await storage.loadLocal()
        XCTAssertEqual(local.first?.messages.map(\.content), ["Keep me"])
    }

    func test_cancel_concurrentCallersKeepAdmissionClosedUntilSharedDrainCompletes() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        let conversation = Conversation(title: "Original", modelId: "model")
        try await storage.save(conversation)
        let runStarted = expectation(description: "Synchronization started")
        let releaseRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            runStarted.fulfill()
            releaseRun.wait()
        }
        let sut = ConversationSyncCoordinator(storage: storage)
        let synchronization = Task { await sut.synchronize() }
        await fulfillment(of: [runStarted], timeout: 2)
        let firstCancellation = Task { await sut.cancel() }
        let secondCancellation = Task { await sut.cancel() }
        let mutation = Task {
            let token = await sut.admissionToken()
            return try await sut.rename(
                conversation.id,
                title: "Renamed",
                synchronize: false,
                admissionToken: token
            )
        }
        for _ in 0..<10 { await Task.yield() }

        // When
        let loadCountBeforeRelease = cloudManager.loadConversationsCallCount
        releaseRun.signal()
        await firstCancellation.value
        await secondCancellation.value
        _ = await synchronization.value
        _ = try await mutation.value

        // Then
        let localConversation = try await storage.loadLocal().first
        XCTAssertEqual(loadCountBeforeRelease, 1)
        XCTAssertEqual(localConversation?.title, "Renamed")
    }

    func test_cancel_saveWithTokenAdmittedAtCancellationBoundary_retriesAfterDrain() async throws {
        // Given
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cloudManager = MockCloudSyncManager()
        let base = Conversation(modelId: "model")
        let storage = ConversationStorage(
            cloudSyncManager: cloudManager,
            attachmentRepository: MockAttachmentRepository(),
            baseDirectory: directory
        )
        try await storage.save(base)
        let runStarted = expectation(description: "Synchronization started")
        let releaseRun = DispatchSemaphore(value: 0)
        cloudManager.loadConversationsHandler = {
            runStarted.fulfill()
            releaseRun.wait()
        }
        let sut = ConversationSyncCoordinator(storage: storage)
        let token = await sut.admissionToken()
        let synchronization = Task { await sut.synchronize() }
        await fulfillment(of: [runStarted], timeout: 2)
        let cancellation = Task { await sut.cancel() }
        for _ in 0..<10 { await Task.yield() }
        cloudManager.cloudAvailable = false
        var updated = base
        updated.messages = [ChatMessage(role: .user, content: "Persist after cancellation")]
        updated.updatedAt = Date()
        let save = Task {
            try await sut.save(
                updated,
                expectedBase: base,
                synchronize: true,
                admissionToken: token
            )
        }

        // When
        releaseRun.signal()
        await cancellation.value
        _ = await synchronization.value
        _ = try await save.value

        // Then
        let localConversation = try await storage.loadLocal().first
        let pendingBase = try await storage.loadPendingMutationBases()[base.id]
        let canonicalBase = try SyncJSONCoding.makeDecoder().decode(
            Conversation.self,
            from: SyncJSONCoding.makeEncoder().encode(base)
        )
        XCTAssertEqual(localConversation?.messages.map(\.content), ["Persist after cancellation"])
        XCTAssertEqual(pendingBase, canonicalBase)
    }
}
