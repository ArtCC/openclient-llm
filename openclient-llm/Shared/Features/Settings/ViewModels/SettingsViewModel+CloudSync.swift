//
//  SettingsViewModel+CloudSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension SettingsViewModel {
    func handleCloudSyncEvent(_ event: Event) {
        switch event {
        case .cloudSyncToggled(let enabled):
            if enabled {
                enableCloudSync()
            } else {
                disableCloudSync()
            }
        case .cloudSyncConflictResolved(let keepLocal):
            resolveCloudSyncConflict(keepLocal: keepLocal)
        case .cloudSyncConflictCancelled:
            dismissCloudSyncConflict()
        case .syncNowTapped:
            synchronizeAppData()
        case .cloudSyncRetryTapped:
            retryCloudSync()
        case .cloudAccountReviewConfirmed:
            approveCloudAccount()
        case .cloudAccountReviewCancelled:
            cancelCloudAccountReview()
        case .cloudAccountReviewDismissed:
            dismissCloudAccountReview()
        default:
            break
        }
    }

    func refreshCloudAvailability() {
        guard settingsManager.getIsCloudSyncEnabled(),
              cloudSyncRuntimeStore.status != .synchronizing else { return }
        cloudSyncCoordinator.start()
    }
}

// MARK: - Private

private extension SettingsViewModel {
    func enableCloudSync() {
        guard cloudAccountAssociation.state() == .matched else {
            presentCloudAccountReview()
            return
        }
        activateCloudSync(approvingCurrentAccount: false)
    }

    func activateCloudSync(approvingCurrentAccount: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        cloudSyncGeneration += 1
        let generation = cloudSyncGeneration
        cloudEnableTask?.cancel()
        cloudEnableTask = nil
        synchronizationTask?.cancel()
        synchronizationTask = nil
        settingsManager.setIsCloudSyncEnabled(true)
        loadedState.isCloudSyncEnabled = true
        loadedState.showCloudSyncConflictAlert = false
        loadedState.showCloudAccountReviewAlert = false
        loadedState.synchronizationResult = nil
        state = .loaded(loadedState)
        let profileConflictHandler = { [weak self] in
            guard let self, isCurrentCloudOperation(generation) else { return }
            presentProfileConflict()
        }
        if approvingCurrentAccount {
            cloudSyncCoordinator.approveCurrentAccount(profileConflictHandler: profileConflictHandler)
        } else {
            cloudSyncCoordinator.start(profileConflictHandler: profileConflictHandler)
        }
    }

    func disableCloudSync() {
        guard case .loaded(var loadedState) = state else { return }
        cloudSyncGeneration += 1
        settingsManager.setIsCloudSyncEnabled(false)
        cloudEnableTask?.cancel()
        cloudEnableTask = nil
        synchronizationTask?.cancel()
        synchronizationTask = nil
        loadedState.isCloudSyncEnabled = false
        loadedState.showCloudSyncConflictAlert = false
        loadedState.showCloudAccountReviewAlert = false
        loadedState.synchronizationResult = nil
        state = .loaded(loadedState)
        cloudSyncRuntimeStore.publish(.disabled)
        cloudSyncCoordinator.stop()
    }

    func synchronizeAppData() {
        guard case .loaded(let loadedState) = state,
              loadedState.isCloudSyncEnabled,
              synchronizationTask == nil else { return }
        let generation = cloudSyncGeneration
        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            let result = await synchronizeAppDataUseCase.execute()
            guard !Task.isCancelled, isCurrentCloudOperation(generation) else { return }
            guard case .loaded(var currentState) = state else { return }
            currentState.synchronizationResult = result
            currentState.showCloudSyncConflictAlert = !result.categories(with: .conflict).isEmpty
            state = .loaded(currentState)
            synchronizationTask = nil
        }
    }

    func resolveCloudSyncConflict(keepLocal: Bool) {
        guard case .loaded(var loadedState) = state, loadedState.isCloudSyncEnabled else { return }
        cloudSyncGeneration += 1
        let generation = cloudSyncGeneration
        loadedState.showCloudSyncConflictAlert = false
        state = .loaded(loadedState)
        cloudSyncRuntimeStore.publish(.synchronizing)
        cloudEnableTask?.cancel()
        cloudEnableTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard !Task.isCancelled, isCurrentCloudOperation(generation) else { return }
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: keepLocal)
                guard !Task.isCancelled, isCurrentCloudOperation(generation) else { return }
                cloudSyncCoordinator.start()
            } catch {
                guard !Task.isCancelled, isCurrentCloudOperation(generation) else { return }
                cloudSyncRuntimeStore.publish(.failed(.init(
                    reason: error is CloudSyncManifest.ValidationError ? .unsupportedSchema : .fileAccess,
                    affectedCategories: [.profile]
                )))
            }
            if cloudSyncGeneration == generation { cloudEnableTask = nil }
        }
    }

    func dismissCloudSyncConflict() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudSyncConflictAlert = false
        state = .loaded(loadedState)
    }

    func retryCloudSync() {
        if case .failed(let failure) = cloudSyncRuntimeStore.status,
           failure.reason == .accountChanged {
            presentCloudAccountReview()
        } else {
            enableCloudSync()
        }
    }

    func presentCloudAccountReview() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudAccountReviewAlert = true
        state = .loaded(loadedState)
    }

    func approveCloudAccount() {
        activateCloudSync(approvingCurrentAccount: true)
    }

    func cancelCloudAccountReview() {
        disableCloudSync()
    }

    func dismissCloudAccountReview() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudAccountReviewAlert = false
        state = .loaded(loadedState)
    }

    func presentProfileConflict() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudSyncConflictAlert = true
        state = .loaded(loadedState)
        cloudSyncRuntimeStore.publish(.failed(.init(reason: .profileConflict, affectedCategories: [.profile])))
    }

    func isCurrentCloudOperation(_ generation: Int) -> Bool {
        generation == cloudSyncGeneration && settingsManager.getIsCloudSyncEnabled()
    }
}
