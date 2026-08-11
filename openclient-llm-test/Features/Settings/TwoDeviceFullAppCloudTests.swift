//
//  TwoDeviceFullAppCloudTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TwoDeviceFullAppCloudTests: XCTestCase {
    // MARK: - Tests

    func test_synchronize_mixedCategories_convergesAcrossBothDevices() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let conversation = Conversation(
            title: "Conversation A",
            modelId: "model",
            createdAt: revision(1_000),
            updatedAt: revision(1_000)
        )
        try harness.deviceA.writeConversation(conversation)
        try await saveLocalProfile(
            UserProfile(name: "Profile B", modifiedAt: revision(2_000)),
            on: harness.deviceB
        )
        let memory = MemoryItem(content: "Memory A", createdAt: revision(1_000))
        try write(memoryItems: [memory], on: harness.deviceA)
        let template = PromptTemplate(
            title: "Template B",
            content: "Body",
            createdAt: revision(2_000)
        )
        try write(template: template, on: harness.deviceB)

        // When
        let first = await harness.synchronize(harness.deviceA)
        let second = await harness.synchronize(harness.deviceB)
        let third = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertTrue(first.isSuccessful)
        XCTAssertTrue(second.isSuccessful)
        XCTAssertTrue(third.isSuccessful)
        let conversationsA = try await harness.deviceA.conversations.loadLocal()
        let conversationsB = try await harness.deviceB.conversations.loadLocal()
        let templateIDsA = try await harness.deviceA.customTemplates().map(\.id)
        XCTAssertEqual(conversationsA, [conversation])
        XCTAssertEqual(conversationsB, [conversation])
        XCTAssertEqual(harness.deviceA.profile.getLocalProfile().name, "Profile B")
        XCTAssertEqual(harness.deviceB.memory.getItems(), [memory])
        XCTAssertEqual(templateIDsA, [template.id])
    }

    func test_synchronize_repeatedMixedCategoryRun_preservesExactBytes() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        try harness.deviceA.writeConversation(Conversation(title: "Stable", modelId: "model"))
        try write(memoryItems: [MemoryItem(content: "Stable")], on: harness.deviceA)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        let cloud = try harness.cloudBytes()
        let localA = try harness.bytes(in: harness.deviceA.documentsURL)
        let localB = try harness.bytes(in: harness.deviceB.documentsURL)

        // When
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertEqual(try harness.cloudBytes(), cloud)
        XCTAssertEqual(try harness.bytes(in: harness.deviceA.documentsURL), localA)
        XCTAssertEqual(try harness.bytes(in: harness.deviceB.documentsURL), localB)
    }

    func test_deleteAll_globalPurgeJournal_blocksStaleSecondDeviceResurrection() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let conversation = Conversation(title: "Stale", modelId: "model", updatedAt: revision(1_000))
        let memory = MemoryItem(content: "Stale", createdAt: revision(1_000))
        let template = PromptTemplate(title: "Stale", content: "Body", createdAt: revision(1_000))
        try harness.deviceA.writeConversation(conversation)
        try write(memoryItems: [memory], on: harness.deviceA)
        try write(template: template, on: harness.deviceA)
        try await saveLocalProfile(UserProfile(name: "Stale", modifiedAt: revision(1_000)), on: harness.deviceA)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)

        // When
        let deletion = try await harness.deviceA.cloudDataManagement.deleteAll()
        let staleDeviceResult = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertTrue(deletion.failedCategories.isEmpty)
        XCTAssertTrue(staleDeviceResult.isSuccessful)
        let conversationsB = try await harness.deviceB.conversations.loadLocal()
        let templatesB = try await harness.deviceB.customTemplates()
        XCTAssertTrue(conversationsB.isEmpty)
        XCTAssertTrue(harness.deviceB.memory.getItems().isEmpty)
        XCTAssertTrue(templatesB.isEmpty)
        XCTAssertEqual(try harness.deviceB.profile.getLocalProfileState(), .missing)
        let journal = try await harness.deviceA.cloud.loadCloudPurgeJournal()
        XCTAssertEqual(journal?.unfinishedCategories, Set<CloudDataCategory>())
    }

    func test_deleteAll_newerMemoryRecreation_survivesPurgeAndDownloadsToSecondDevice() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        try write(memoryItems: [MemoryItem(content: "Old", createdAt: revision(1_000))], on: harness.deviceA)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        let deletion = try await harness.deviceA.cloudDataManagement.deleteAll()
        let recreated = MemoryItem(
            content: "Recreated",
            createdAt: deletion.marker.deletedAt.addingTimeInterval(1)
        )

        // When
        try await harness.deviceA.memory.add(recreated)
        _ = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(harness.deviceA.memory.getItems().map(\.content), ["Recreated"])
        XCTAssertEqual(harness.deviceB.memory.getItems().map(\.content), ["Recreated"])
    }

    func test_synchronize_corruptMemory_reportsPartialFailureWhileOtherCategoriesConverge() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let conversation = Conversation(title: "Valid", modelId: "model")
        let template = PromptTemplate(
            title: "Valid",
            content: "Body",
            createdAt: revision(1_000),
            updatedAt: revision(1_000)
        )
        try harness.deviceA.writeConversation(conversation)
        try write(template: template, on: harness.deviceA)
        try Data("not-json".utf8).write(
            to: harness.deviceA.documentsURL.appendingPathComponent("Memory.json"),
            options: .atomic
        )

        // When
        let result = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(result.outcomes[.memory], .failed)
        XCTAssertEqual(result.outcomes[.conversations], .synchronized)
        XCTAssertEqual(result.outcomes[.promptTemplates], .synchronized)
        let conversationIDs = try await harness.deviceB.conversations.loadLocal().map(\.id)
        let templateIDs = try await harness.deviceB.customTemplates().map(\.id)
        XCTAssertEqual(conversationIDs, [conversation.id])
        XCTAssertEqual(templateIDs, [template.id])
        XCTAssertEqual(
            try Data(contentsOf: harness.deviceA.documentsURL.appendingPathComponent("Memory.json")),
            Data("not-json".utf8)
        )
    }

    func test_synchronize_metadataPending_reportsPendingAcrossEveryCategoryWithoutWriting() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        try harness.deviceA.writeConversation(Conversation(title: "Cloud", modelId: "model"))
        _ = await harness.synchronize(harness.deviceA)
        try harness.deviceB.writeConversation(Conversation(title: "Pending local", modelId: "model"))
        let original = try harness.cloudBytes()
        harness.cloudProvider.setMetadataReady(false)

        // When
        let result = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(result.categories(with: .pendingDownload), Set(AppSynchronizationResult.Category.allCases))
        XCTAssertEqual(try harness.cloudBytes(), original)
    }

    func test_synchronize_cloudUnavailable_reportsUnavailableAcrossEveryCategoryWithoutWriting() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        try harness.deviceA.writeConversation(Conversation(title: "Cloud", modelId: "model"))
        _ = await harness.synchronize(harness.deviceA)
        try harness.deviceB.writeConversation(Conversation(title: "Unavailable local", modelId: "model"))
        let original = try harness.cloudBytes()
        harness.cloudProvider.setAvailable(false)

        // When
        let result = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(result.categories(with: .unavailable), Set(AppSynchronizationResult.Category.allCases))
        XCTAssertEqual(try harness.cloudBytes(), original)
    }

    func test_synchronize_accountSwitchWithoutExplicitResolution_doesNotUploadPreviousAccountData() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let previousAccountConversation = Conversation(title: "Account A", modelId: "model")
        try harness.deviceB.writeConversation(previousAccountConversation)
        _ = await harness.synchronize(harness.deviceB)
        let originalLocal = try harness.bytes(in: harness.deviceB.documentsURL)
        let accountB = try harness.switchCloudAccount(
            to: "AccountB",
            identity: Data("account-b".utf8),
            metadataReady: true
        )
        let originalAccountB = try harness.bytes(in: accountB.appendingPathComponent("Documents", isDirectory: true))

        // When
        let blockedResult = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(blockedResult.categories(with: .failed), Set(AppSynchronizationResult.Category.allCases))
        XCTAssertEqual(Set(blockedResult.failureReasons.values), [.accountChanged])
        XCTAssertEqual(
            try harness.bytes(in: accountB.appendingPathComponent("Documents", isDirectory: true)),
            originalAccountB
        )
        XCTAssertEqual(try harness.bytes(in: harness.deviceB.documentsURL), originalLocal)
        let accountBConversation = accountB
            .appendingPathComponent("Documents/Conversations", isDirectory: true)
            .appendingPathComponent("\(previousAccountConversation.id.uuidString).json")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: accountBConversation.path),
            "Account B must remain isolated until the user explicitly resolves local data from account A."
        )
    }

    func test_synchronize_accountSwitchExplicitPreflightAndApproval_allowsDeterministicMerge() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let previousAccountConversation = Conversation(title: "Account A", modelId: "model")
        try harness.deviceB.writeConversation(previousAccountConversation)
        _ = await harness.synchronize(harness.deviceB)
        let accountB = try harness.switchCloudAccount(
            to: "AccountB",
            identity: Data("account-b".utf8),
            metadataReady: true
        )
        let accountBConversation = Conversation(title: "Account B", modelId: "model")
        let accountBConversationURL = accountB
            .appendingPathComponent("Documents/Conversations", isDirectory: true)
            .appendingPathComponent("\(accountBConversation.id.uuidString).json")
        try FileManager.default.createDirectory(
            at: accountBConversationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try SyncJSONCoding.makeEncoder().encode(accountBConversation).write(
            to: accountBConversationURL,
            options: .atomic
        )

        // When
        let preflight = try await harness.deviceB.preflightAndApproveCurrentAccount()
        let result = await harness.synchronize(harness.deviceB)

        // Then
        XCTAssertEqual(preflight, .ready)
        XCTAssertTrue(result.isSuccessful)
        let mergedIDs = Set(try await harness.deviceB.conversations.loadLocal().map(\.id))
        XCTAssertEqual(mergedIDs, [previousAccountConversation.id, accountBConversation.id])
    }

    func test_approveCurrentAccount_pendingMetadata_doesNotReplaceAcceptedAssociation() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let acceptedFingerprint = harness.deviceB.settings.getAcceptedCloudAccountFingerprint()
        _ = try harness.switchCloudAccount(
            to: "AccountB",
            identity: Data("account-b".utf8),
            metadataReady: false
        )

        // When / Then
        do {
            _ = try await harness.deviceB.preflightAndApproveCurrentAccount()
            XCTFail("Expected pending metadata")
        } catch CloudSyncPreflightError.issues(let issues) {
            XCTAssertEqual(issues.pendingCategories, Set(CloudSyncStatus.DataCategory.allCases))
        }
        XCTAssertEqual(harness.deviceB.settings.getAcceptedCloudAccountFingerprint(), acceptedFingerprint)
        XCTAssertEqual(harness.deviceB.accountAssociation.state(), .changed)
    }
}

// MARK: - Private

private extension TwoDeviceFullAppCloudTests {
    func revision(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }

    func saveLocalProfile(
        _ profile: UserProfile,
        on device: TwoDeviceCloudHarness.Device
    ) async throws {
        device.settings.setIsCloudSyncEnabled(false)
        try await device.profile.saveProfile(profile)
        device.settings.setIsCloudSyncEnabled(true)
    }

    func write(memoryItems: [MemoryItem], on device: TwoDeviceCloudHarness.Device) throws {
        try SyncJSONCoding.makeEncoder().encode(memoryItems).write(
            to: device.documentsURL.appendingPathComponent("Memory.json"),
            options: .atomic
        )
    }

    func write(template: PromptTemplate, on device: TwoDeviceCloudHarness.Device) throws {
        let directory = device.documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SyncJSONCoding.makeEncoder().encode(template).write(
            to: directory.appendingPathComponent("\(template.id.uuidString).json"),
            options: .atomic
        )
    }
}
