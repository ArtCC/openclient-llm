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
    private let settingsManager: SettingsManagerProtocol
    private let synchronizationGate: FullAppSynchronizationGate
    private let mutationGate: CloudSynchronizationMutationGate
    private let runtimeStore: CloudSyncRuntimeStoreProtocol
    private let accountAssociation: CloudAccountAssociationProtocol
    private let now: @Sendable () -> Date

    // MARK: - Init

    init(
        syncConversationsUseCase: SyncConversationsUseCaseProtocol = SyncConversationsUseCase(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        promptTemplateRepository: PromptTemplateRepositoryProtocol = PromptTemplateRepository(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        synchronizationGate: FullAppSynchronizationGate = .shared,
        mutationGate: CloudSynchronizationMutationGate = .shared,
        runtimeStore: CloudSyncRuntimeStoreProtocol = CloudSyncRuntimeStore.shared,
        accountAssociation: CloudAccountAssociationProtocol = CloudAccountAssociation.shared,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.syncConversationsUseCase = syncConversationsUseCase
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
        self.promptTemplateRepository = promptTemplateRepository
        self.settingsManager = settingsManager
        self.synchronizationGate = synchronizationGate
        self.mutationGate = mutationGate
        self.runtimeStore = runtimeStore
        self.accountAssociation = accountAssociation
        self.now = now
    }

    // MARK: - Execute

    func execute() async -> AppSynchronizationResult {
        guard settingsManager.getIsCloudSyncEnabled() else {
            return AppSynchronizationResult(outcomes: [:], isCancelled: true)
        }
        if let blockedResult = accountAssociationResult() {
            publishAssociationBarrier(blockedResult)
            return blockedResult
        }
        guard runtimeStore.isPreflightComplete else {
            return AppSynchronizationResult(outcomes: [:], isCancelled: true)
        }
        let runtimeGeneration = runtimeStore.begin(.synchronizing)
        let result = await synchronizationGate.perform {
            do {
                return try await mutationGate.perform {
                    try await self.checkCloudIntent()
                    if let blockedResult = await self.accountAssociationResult() { return blockedResult }
                    return await self.executeCategories()
                }
            } catch {
                if error is CancellationError {
                    return AppSynchronizationResult(outcomes: [:], isCancelled: true)
                }
                let reason = await self.failureReason(for: error)
                return AppSynchronizationResult(
                    outcomes: Dictionary(uniqueKeysWithValues: AppSynchronizationResult.Category.allCases.map {
                        ($0, .failed)
                    }),
                    failureReasons: Dictionary(uniqueKeysWithValues: AppSynchronizationResult.Category.allCases.map {
                        ($0, reason)
                    }),
                    isCancelled: false
                )
            }
        }
        publish(result, generation: runtimeGeneration)
        return result
    }

    func cancel() async {
        await synchronizationGate.cancel()
        await syncConversationsUseCase.cancel()
    }
}

// MARK: - Private

private extension SynchronizeAppDataUseCase {
    func checkCloudIntent() throws {
        try Task.checkCancellation()
        guard settingsManager.getIsCloudSyncEnabled() else { throw CancellationError() }
    }

    func accountAssociationResult() -> AppSynchronizationResult? {
        switch accountAssociation.state() {
        case .matched:
            return nil
        case .unavailable:
            return AppSynchronizationResult(outcomes: allOutcomes(.unavailable), isCancelled: false)
        case .unassociated, .changed:
            return AppSynchronizationResult(
                outcomes: allOutcomes(.failed),
                failureReasons: allFailureReasons(.accountChanged),
                isCancelled: false
            )
        }
    }

    func allOutcomes(
        _ outcome: AppSynchronizationResult.Outcome
    ) -> [AppSynchronizationResult.Category: AppSynchronizationResult.Outcome] {
        Dictionary(uniqueKeysWithValues: AppSynchronizationResult.Category.allCases.map { ($0, outcome) })
    }

    func allFailureReasons(
        _ reason: CloudSyncStatus.FailureReason
    ) -> [AppSynchronizationResult.Category: CloudSyncStatus.FailureReason] {
        Dictionary(uniqueKeysWithValues: AppSynchronizationResult.Category.allCases.map { ($0, reason) })
    }

    func executeCategories() async -> AppSynchronizationResult {
        var outcomes: [AppSynchronizationResult.Category: AppSynchronizationResult.Outcome] = [:]
        var reasons: [AppSynchronizationResult.Category: CloudSyncStatus.FailureReason] = [:]
        guard !Task.isCancelled else { return .init(outcomes: outcomes, isCancelled: true) }
        if let blockedResult = accountAssociationResult() { return blockedResult }
        outcomes[.conversations] = await conversationOutcome()
        if outcomes[.conversations] == .failed { reasons[.conversations] = .other }
        guard !Task.isCancelled else { return .init(outcomes: outcomes, isCancelled: true) }
        if let blockedResult = accountAssociationResult() { return blockedResult }
        let profile = await profileOutcome()
        outcomes[.profile] = profile.outcome
        reasons[.profile] = profile.reason
        guard !Task.isCancelled else { return .init(outcomes: outcomes, isCancelled: true) }
        if let blockedResult = accountAssociationResult() { return blockedResult }
        let memory = await throwingOutcome { try await memoryManager.synchronize() }
        outcomes[.memory] = memory.outcome
        reasons[.memory] = memory.reason
        guard !Task.isCancelled else { return .init(outcomes: outcomes, isCancelled: true) }
        if let blockedResult = accountAssociationResult() { return blockedResult }
        let templates = await throwingOutcome { _ = try await promptTemplateRepository.loadAll() }
        outcomes[.promptTemplates] = templates.outcome
        reasons[.promptTemplates] = templates.reason
        return AppSynchronizationResult(outcomes: outcomes, failureReasons: reasons)
    }

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

    func profileOutcome() async -> CategoryOutcome {
        do {
            try Task.checkCancellation()
            let localState = try userProfileManager.getLocalProfileState()
            try Task.checkCancellation()
            let cloudState = try await userProfileManager.getCloudProfileState()

            switch (localState, cloudState) {
            case (.missing, .missing), (.missing, .deleted):
                return .init(outcome: .synchronized)
            case (.missing, .profile):
                try Task.checkCancellation()
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: false)
            case (.profile, .missing):
                try Task.checkCancellation()
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: true)
            case (.profile(let localProfile), .deleted(let marker)):
                try Task.checkCancellation()
                try await userProfileManager.resolveCloudSyncConflict(
                    keepLocal: localProfile.modifiedAt > marker.deletedAt
                )
            case (.profile(let localProfile), .profile(let cloudProfile)):
                if localProfile == cloudProfile { return .init(outcome: .synchronized) }
                if cloudProfile.modifiedAt > localProfile.modifiedAt {
                    try Task.checkCancellation()
                    try await userProfileManager.resolveCloudSyncConflict(keepLocal: false)
                } else if localProfile.modifiedAt > cloudProfile.modifiedAt {
                    try Task.checkCancellation()
                    try await userProfileManager.resolveCloudSyncConflict(keepLocal: true)
                } else {
                    return .init(outcome: .conflict, reason: .profileConflict)
                }
            }
            return .init(outcome: .synchronized)
        } catch {
            return categoryOutcome(for: error)
        }
    }

    func throwingOutcome(
        _ operation: @escaping @MainActor () async throws -> Void
    ) async -> CategoryOutcome {
        do {
            try await operation()
            return .init(outcome: .synchronized)
        } catch {
            return categoryOutcome(for: error)
        }
    }

    func categoryOutcome(for error: Error) -> CategoryOutcome {
        guard let cloudError = error as? CloudSyncError else {
            return .init(outcome: .failed, reason: failureReason(for: error))
        }
        switch cloudError {
        case .requiredDownloadPending:
            return .init(outcome: .pendingDownload)
        case .containerUnavailable, .containerIdentityChanged:
            return .init(outcome: .unavailable)
        default:
            return .init(outcome: .failed, reason: failureReason(for: error))
        }
    }

    func failureReason(for error: Error) -> CloudSyncStatus.FailureReason {
        if error is CloudSyncManifest.ValidationError { return .unsupportedSchema }
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteOutOfSpace {
            return .insufficientStorage
        }
        switch error as? CloudSyncError {
        case .invalidAttachmentPath, .invalidConversationData, .invalidProfileData:
            return .invalidData
        case .conflictingProfileRevision:
            return .profileConflict
        case .missingAttachment, .cloudContentChanged, .staleConversationRevision, .staleProfileRevision:
            return .fileAccess
        default:
            return .other
        }
    }

    func publishAssociationBarrier(_ result: AppSynchronizationResult) {
        guard !result.isCancelled else { return }
        if result.failureReasons.values.contains(.accountChanged) {
            runtimeStore.publish(.failed(.init(
                reason: .accountChanged,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )))
        } else {
            runtimeStore.publish(.incomplete(result.cloudSyncIssues))
        }
    }

    func publish(_ result: AppSynchronizationResult, generation: Int) {
        guard settingsManager.getIsCloudSyncEnabled() else {
            runtimeStore.publish(.disabled)
            return
        }
        if result.isCancelled { return }
        if result.failureReasons.values.contains(.accountChanged) {
            runtimeStore.publish(.failed(.init(
                reason: .accountChanged,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )), generation: generation)
            return
        }
        if result.isSuccessful {
            let date = now()
            if runtimeStore.publish(.synchronized(lastSuccessfulSyncAt: date), generation: generation) {
                settingsManager.setLastSuccessfulCloudSyncDate(date)
            }
            return
        }
        runtimeStore.publish(.incomplete(result.cloudSyncIssues), generation: generation)
    }
}

private extension SynchronizeAppDataUseCase {
    struct CategoryOutcome {
        let outcome: AppSynchronizationResult.Outcome
        let reason: CloudSyncStatus.FailureReason?

        init(
            outcome: AppSynchronizationResult.Outcome,
            reason: CloudSyncStatus.FailureReason? = nil
        ) {
            self.outcome = outcome
            self.reason = reason
        }
    }
}
