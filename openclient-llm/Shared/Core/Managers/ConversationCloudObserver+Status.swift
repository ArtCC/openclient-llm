//
//  ConversationCloudObserver+Status.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationCloudObserver {
    func canStartForAssociatedAccount() -> Bool {
        switch accountAssociation.state() {
        case .unassociated, .changed:
            runtimeStore.publish(.failed(.init(
                reason: .accountChanged,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )))
            return false
        case .unavailable, .matched:
            return true
        }
    }

    func approveAccount(fingerprint: String?, generation: Int, runtimeGeneration: Int) -> Bool {
        guard let fingerprint else {
            completeAccountAssociationFailure(
                CloudAccountAssociationError.unavailable,
                generation: generation,
                runtimeGeneration: runtimeGeneration
            )
            return false
        }
        do {
            try accountAssociation.approveCurrentAccount(expectedFingerprint: fingerprint)
            return true
        } catch {
            completeAccountAssociationFailure(error, generation: generation, runtimeGeneration: runtimeGeneration)
            return false
        }
    }

    func completeProfileConflict(generation: Int, runtimeGeneration: Int) {
        guard generation == startGeneration,
              settingsManager.getIsCloudSyncEnabled() else { return }
        startTask = nil
        guard runtimeStore.publish(.failed(.init(
            reason: .profileConflict,
            affectedCategories: [.profile]
        )), generation: runtimeGeneration) else { return }
        profileConflictHandler?()
        profileConflictHandler = nil
    }

    func completePreflightFailure(_ error: Error, generation: Int, runtimeGeneration: Int) {
        guard generation == startGeneration,
              settingsManager.getIsCloudSyncEnabled(),
              !(error is CancellationError) else { return }
        startTask = nil
        switch error as? CloudSyncPreflightError {
        case .accountUnavailable:
            runtimeStore.publish(.unavailable(.accountUnavailable), generation: runtimeGeneration)
        case .containerUnavailable:
            runtimeStore.publish(.unavailable(.containerUnavailable), generation: runtimeGeneration)
        case .issues(let issues):
            runtimeStore.publish(.incomplete(issues), generation: runtimeGeneration)
        case nil:
            runtimeStore.publish(.failed(.init(
                reason: .fileAccess,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )), generation: runtimeGeneration)
        }
    }

    func completeAccountAssociationFailure(_ error: Error, generation: Int, runtimeGeneration: Int) {
        guard generation == startGeneration,
              settingsManager.getIsCloudSyncEnabled(),
              !(error is CancellationError) else { return }
        startTask = nil
        if error as? CloudAccountAssociationError == .unavailable {
            runtimeStore.publish(.unavailable(.accountUnavailable), generation: runtimeGeneration)
        } else {
            runtimeStore.publish(.failed(.init(
                reason: .accountChanged,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )), generation: runtimeGeneration)
        }
    }

    func notifyConsumers(for result: AppSynchronizationResult) {
        if result.outcomes[.conversations] == .synchronized {
            notificationCenter.post(name: .conversationDidUpdate, object: nil)
        }
        if result.outcomes[.profile] == .synchronized {
            notificationCenter.post(name: UserProfileManager.profileDidChangeExternallyNotification, object: nil)
        }
        if result.outcomes[.memory] == .synchronized {
            notificationCenter.post(name: MemoryManager.memoryDidChangeExternallyNotification, object: nil)
        }
        if result.outcomes[.promptTemplates] == .synchronized {
            notificationCenter.post(name: .promptTemplatesDidChangeExternally, object: nil)
        }
    }

    func publishMetadataPending() {
        guard runtimeStore.status != .synchronizing else { return }
        runtimeStore.publish(.waitingForDownloads)
    }
}
