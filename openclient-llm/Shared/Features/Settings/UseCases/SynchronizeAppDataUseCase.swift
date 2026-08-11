//
//  SynchronizeAppDataUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SynchronizeAppDataUseCaseProtocol: Sendable {
    func execute() async -> AppSynchronizationResult
    func cancel() async
}

struct SynchronizeAppDataUseCase: SynchronizeAppDataUseCaseProtocol {
    // MARK: - Properties

    private let syncConversationsUseCase: SyncConversationsUseCaseProtocol
    private let userProfileManager: UserProfileManagerProtocol
    private let memoryManager: MemoryManagerProtocol
    private let promptTemplateRepository: PromptTemplateRepositoryProtocol

    // MARK: - Init

    init(
        syncConversationsUseCase: SyncConversationsUseCaseProtocol = SyncConversationsUseCase(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        promptTemplateRepository: PromptTemplateRepositoryProtocol = PromptTemplateRepository()
    ) {
        self.syncConversationsUseCase = syncConversationsUseCase
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
        self.promptTemplateRepository = promptTemplateRepository
    }

    // MARK: - Execute

    func execute() async -> AppSynchronizationResult {
        var outcomes: [AppSynchronizationResult.Category: AppSynchronizationResult.Outcome] = [:]
        outcomes[.conversations] = await conversationOutcome()
        guard !Task.isCancelled else { return AppSynchronizationResult(outcomes: outcomes) }
        outcomes[.profile] = await profileOutcome()
        guard !Task.isCancelled else { return AppSynchronizationResult(outcomes: outcomes) }
        outcomes[.memory] = await throwingOutcome { try await memoryManager.synchronize() }
        guard !Task.isCancelled else { return AppSynchronizationResult(outcomes: outcomes) }
        outcomes[.promptTemplates] = await throwingOutcome { _ = try await promptTemplateRepository.loadAll() }
        return AppSynchronizationResult(outcomes: outcomes)
    }

    func cancel() async {
        await syncConversationsUseCase.cancel()
    }
}

// MARK: - Private

private extension SynchronizeAppDataUseCase {
    func conversationOutcome() async -> AppSynchronizationResult.Outcome {
        switch await syncConversationsUseCase.execute() {
        case .synchronized:
            .synchronized
        case .pendingDownload:
            .pendingDownload
        case .unavailable:
            .unavailable
        case .failed:
            .failed
        }
    }

    func profileOutcome() async -> AppSynchronizationResult.Outcome {
        do {
            let cloudState = try await userProfileManager.getCloudProfileState()
            let localProfile = userProfileManager.getLocalProfile()

            switch cloudState {
            case .missing, .deleted:
                guard !localProfile.isEmpty else { return .synchronized }
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: true)
            case .profile(let cloudProfile):
                if localProfile == cloudProfile { return .synchronized }
                if localProfile.isEmpty || cloudProfile.modifiedAt > localProfile.modifiedAt {
                    try await userProfileManager.resolveCloudSyncConflict(keepLocal: false)
                } else if localProfile.modifiedAt > cloudProfile.modifiedAt {
                    try await userProfileManager.resolveCloudSyncConflict(keepLocal: true)
                } else {
                    return .conflict
                }
            }
            return .synchronized
        } catch {
            return outcome(for: error)
        }
    }

    func throwingOutcome(
        _ operation: @escaping @MainActor () async throws -> Void
    ) async -> AppSynchronizationResult.Outcome {
        do {
            try await operation()
            return .synchronized
        } catch {
            return outcome(for: error)
        }
    }

    func outcome(for error: Error) -> AppSynchronizationResult.Outcome {
        guard let cloudError = error as? CloudSyncError else { return .failed }
        switch cloudError {
        case .requiredDownloadPending:
            return .pendingDownload
        case .containerUnavailable, .containerIdentityChanged:
            return .unavailable
        default:
            return .failed
        }
    }
}
