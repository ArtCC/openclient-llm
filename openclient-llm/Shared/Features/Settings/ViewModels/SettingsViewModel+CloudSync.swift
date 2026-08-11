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
            toggleCloudSync(enabled)
        case .cloudSyncConflictResolved(let keepLocal):
            resolveCloudSyncConflict(keepLocal: keepLocal)
        case .cloudSyncConflictCancelled:
            cancelCloudSyncToggle()
        case .syncNowTapped:
            synchronizeAppData()
        default:
            break
        }
    }

    func refreshCloudAvailability() async {
        let isAvailable = await cloudSyncManager.checkCloudAvailability()
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isCloudAvailable = isAvailable
        loadedState.isCloudSyncEnabled = settingsManager.getIsCloudSyncEnabled()
        state = .loaded(loadedState)
    }
}

// MARK: - Private

private extension SettingsViewModel {
    func toggleCloudSync(_ enabled: Bool) {
        guard case .loaded(var loadedState) = state else { return }

        if enabled {
            loadedState.isSynchronizing = true
            state = .loaded(loadedState)
            Task { [weak self] in
                await self?.enableCloudSyncAfterPreflight()
            }
        } else {
            disableCloudSync(loadedState: loadedState)
        }
    }

    func disableCloudSync(loadedState: LoadedState) {
        settingsManager.setIsCloudSyncEnabled(false)
        var pendingState = loadedState
        pendingState.synchronizationResult = nil
        pendingState.isSynchronizing = false
        state = .loaded(pendingState)
        synchronizationTask?.cancel()
        synchronizationTask = nil
        Task { [weak self] in
            guard let self else { return }
            await synchronizeAppDataUseCase.cancel()
            guard !settingsManager.getIsCloudSyncEnabled(),
                  case .loaded(var currentState) = state else { return }
            currentState.isCloudSyncEnabled = false
            currentState.synchronizationResult = nil
            currentState.isSynchronizing = false
            state = .loaded(currentState)
        }
    }

    func resolveCloudSyncConflict(keepLocal: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudSyncConflictAlert = false
        loadedState.isSynchronizing = true
        state = .loaded(loadedState)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: keepLocal)
                finishCloudSyncEnablement()
            } catch {
                updateCloudPreflightFailure(error)
            }
        }
    }

    func cancelCloudSyncToggle() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudSyncConflictAlert = false
        state = .loaded(loadedState)
    }

    func synchronizeAppData() {
        guard case .loaded(let loadedState) = state,
              loadedState.isCloudSyncEnabled,
              !loadedState.isSynchronizing else { return }
        var synchronizingState = loadedState
        synchronizingState.isSynchronizing = true
        state = .loaded(synchronizingState)
        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            let result = await synchronizeAppDataUseCase.execute()
            guard !Task.isCancelled else { return }
            guard case .loaded(var currentState) = state, currentState.isCloudSyncEnabled else { return }
            currentState.synchronizationResult = result
            currentState.isSynchronizing = false
            currentState.showCloudSyncConflictAlert = !result.categories(with: .conflict).isEmpty
            state = .loaded(currentState)
            synchronizationTask = nil
        }
    }

    func enableCloudSyncAfterPreflight() async {
        do {
            let cloudState = try await userProfileManager.getCloudProfileState()
            let localProfile = userProfileManager.getLocalProfile()
            guard case .loaded(var loadedState) = state else { return }
            if case .profile(let cloudProfile) = cloudState,
               !localProfile.isEmpty,
               !cloudProfile.isEmpty,
               localProfile != cloudProfile {
                loadedState.showCloudSyncConflictAlert = true
                loadedState.isSynchronizing = false
                state = .loaded(loadedState)
                return
            }
            if !localProfile.isEmpty, cloudState != .profile(localProfile) {
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: true)
            } else if localProfile.isEmpty, case .profile(let cloudProfile) = cloudState, !cloudProfile.isEmpty {
                try await userProfileManager.resolveCloudSyncConflict(keepLocal: false)
            }
            finishCloudSyncEnablement()
        } catch {
            updateCloudPreflightFailure(error)
        }
    }

    func finishCloudSyncEnablement() {
        guard case .loaded(var loadedState) = state else { return }
        settingsManager.setIsCloudSyncEnabled(true)
        loadedState.isCloudSyncEnabled = true
        loadedState.isSynchronizing = false
        state = .loaded(loadedState)
        synchronizeAppData()
    }

    func updateCloudPreflightFailure(_ error: Error) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isCloudSyncEnabled = false
        let outcome: AppSynchronizationResult.Outcome = (error as? CloudSyncError) == .requiredDownloadPending
            ? .pendingDownload
            : .failed
        loadedState.synchronizationResult = AppSynchronizationResult(outcomes: [.profile: outcome])
        loadedState.isSynchronizing = false
        state = .loaded(loadedState)
    }
}
