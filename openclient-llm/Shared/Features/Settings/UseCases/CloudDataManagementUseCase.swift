//
//  CloudDataManagementUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol CloudDataManagementUseCaseProtocol: Sendable {
    func inventory() async -> CloudDataInventory
    func deleteConversation(id: UUID) async throws
    func deleteProfile() async throws
    func deleteMemory(id: UUID) async throws
    func deletePromptTemplate(id: UUID) async throws
    func deleteAll() async throws -> CloudDeletionResult
    func retryDeletion(_ result: CloudDeletionResult) async throws -> CloudDeletionResult
    func resumeDeletion() async throws -> CloudDeletionResult?
}

struct CloudDataManagementUseCase: CloudDataManagementUseCaseProtocol {
    // MARK: - Properties

    private let cloudSyncManager: CloudSyncManagerProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let userProfileManager: UserProfileManagerProtocol
    private let memoryManager: MemoryManagerProtocol
    private let promptTemplateRepository: PromptTemplateRepositoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let mutationGate: CloudSynchronizationMutationGate

    // MARK: - Init

    init(
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        conversationRepository: ConversationRepositoryProtocol = ConversationRepository(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        promptTemplateRepository: PromptTemplateRepositoryProtocol = PromptTemplateRepository(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        mutationGate: CloudSynchronizationMutationGate = .shared
    ) {
        self.cloudSyncManager = cloudSyncManager
        self.conversationRepository = conversationRepository
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
        self.promptTemplateRepository = promptTemplateRepository
        self.settingsManager = settingsManager
        self.mutationGate = mutationGate
    }

    // MARK: - Public

    func inventory() async -> CloudDataInventory {
        await cloudSyncManager.loadCloudInventory()
    }

    func deleteConversation(id: UUID) async throws {
        try requireCloudSyncEnabled()
        try await conversationRepository.deleteSynchronized(id)
        postChangeNotification(for: .conversations)
    }

    func deleteProfile() async throws {
        try requireCloudSyncEnabled()
        try await userProfileManager.deleteSynchronizedProfile()
        postChangeNotification(for: .profile)
    }

    func deleteMemory(id: UUID) async throws {
        try requireCloudSyncEnabled()
        try await memoryManager.deleteSynchronized(id: id)
        postChangeNotification(for: .memory)
    }

    func deletePromptTemplate(id: UUID) async throws {
        try requireCloudSyncEnabled()
        try await promptTemplateRepository.deleteSynchronized(id)
        postChangeNotification(for: .promptTemplates)
    }

    func deleteAll() async throws -> CloudDeletionResult {
        try await performDeletion(categories: Set(CloudDataCategory.allCases), marker: nil)
    }

    func retryDeletion(_ result: CloudDeletionResult) async throws -> CloudDeletionResult {
        let journal = try await cloudSyncManager.loadCloudPurgeJournal()
        let categories = journal?.marker == result.marker
            ? result.failedCategories.intersection(journal?.unfinishedCategories ?? [])
            : result.failedCategories
        guard !categories.isEmpty else { return result }
        let retry = try await performDeletion(categories: categories, marker: result.marker)
        var outcomes = result.outcomes
        outcomes.merge(retry.outcomes) { _, retried in retried }
        return CloudDeletionResult(marker: result.marker, outcomes: outcomes)
    }

    func resumeDeletion() async throws -> CloudDeletionResult? {
        guard let marker = try await cloudSyncManager.loadCloudPurgeMarker() else { return nil }
        let journal = try await cloudSyncManager.loadCloudPurgeJournal()
        guard journal?.marker == marker else {
            return try await performDeletion(categories: Set(CloudDataCategory.allCases), marker: marker)
        }
        guard let journal, !journal.unfinishedCategories.isEmpty else { return nil }
        let resumed = try await performDeletion(categories: journal.unfinishedCategories, marker: marker)
        var outcomes = Dictionary(uniqueKeysWithValues: CloudDataCategory.allCases.compactMap { category in
            journal.categoryStates[category] == .completed
                ? (category, CloudDeletionCategoryOutcome.deleted)
                : nil
        })
        outcomes.merge(resumed.outcomes) { _, resumed in resumed }
        return CloudDeletionResult(marker: marker, outcomes: outcomes)
    }
}

// MARK: - Private

private extension CloudDataManagementUseCase {
    func performDeletion(
        categories: Set<CloudDataCategory>,
        marker: CloudPurgeMarker?
    ) async throws -> CloudDeletionResult {
        try await mutationGate.perform {
            var result = try await cloudSyncManager.deleteCloudData(categories: categories, marker: marker)
            var outcomes = result.outcomes
            for category in categories where outcomes[category] == .deleted {
                do {
                    let journal = try await cloudSyncManager.loadCloudPurgeJournal()
                    guard journal?.categoryStates[category] != .completed else { continue }
                    try await deleteLocalData(for: category, through: result.marker)
                    try await cloudSyncManager.completeLocalPurgeCleanup(category: category, marker: result.marker)
                    postChangeNotification(for: category)
                } catch {
                    outcomes[category] = .failed(.fileAccess)
                }
            }
            result = CloudDeletionResult(marker: result.marker, outcomes: outcomes)
            return result
        }
    }

    func deleteLocalData(for category: CloudDataCategory, through marker: CloudPurgeMarker) async throws {
        switch category {
        case .conversations:
            try await conversationRepository.purgeLocalData(through: marker)
        case .profile:
            try userProfileManager.purgeLocalProfile(through: marker)
        case .memory:
            try memoryManager.purgeLocalData(through: marker)
        case .promptTemplates:
            try await promptTemplateRepository.purgeLocalData(through: marker)
        }
    }

    func requireCloudSyncEnabled() throws {
        guard settingsManager.getIsCloudSyncEnabled() else {
            throw CloudDataManagementError.cloudSyncDisabled
        }
    }

    nonisolated func postChangeNotification(for category: CloudDataCategory) {
        let name: Notification.Name
        switch category {
        case .conversations:
            name = .conversationDidUpdate
        case .profile:
            name = UserProfileManager.profileDidChangeExternallyNotification
        case .memory:
            name = MemoryManager.memoryDidChangeExternallyNotification
        case .promptTemplates:
            name = .promptTemplatesDidChangeExternally
        }
        NotificationCenter.default.post(name: name, object: nil)
    }
}
