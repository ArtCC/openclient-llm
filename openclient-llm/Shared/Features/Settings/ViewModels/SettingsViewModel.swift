//
//  SettingsViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case serverURLChanged(String)
        case apiKeyChanged(String)
        case testConnectionTapped
        case saveTapped
        case cloudSyncToggled(Bool)
        case cloudSyncConflictResolved(keepLocal: Bool)
        case cloudSyncConflictCancelled
        case showTokenUsageToggled(Bool)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var serverURL: String = ""
        var apiKey: String = ""
        var connectionStatus: ConnectionStatus = .idle
        var isSaved: Bool = false
        var isCloudSyncEnabled: Bool = false
        var isCloudAvailable: Bool = false
        var showTokenUsage: Bool = true
        var showCloudSyncConflictAlert: Bool = false
    }

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    private(set) var state: State

    private let saveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol
    private let testServerConnectionUseCase: TestServerConnectionUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let userProfileManager: UserProfileManagerProtocol

    // MARK: - Init

    init(
        state: State = .loading,
        saveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol = SaveServerConfigurationUseCase(),
        testServerConnectionUseCase: TestServerConnectionUseCaseProtocol = TestServerConnectionUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager()
    ) {
        self.state = state
        self.saveServerConfigurationUseCase = saveServerConfigurationUseCase
        self.testServerConnectionUseCase = testServerConnectionUseCase
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.userProfileManager = userProfileManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadSettings()
        case .serverURLChanged(let url):
            updateServerURL(url)
        case .apiKeyChanged(let key):
            updateAPIKey(key)
        case .testConnectionTapped:
            testConnection()
        case .saveTapped:
            saveSettings()
        case .cloudSyncToggled(let enabled):
            toggleCloudSync(enabled)
        case .cloudSyncConflictResolved(let keepLocal):
            resolveCloudSyncConflict(keepLocal: keepLocal)
        case .cloudSyncConflictCancelled:
            cancelCloudSyncToggle()
        case .showTokenUsageToggled(let show):
            toggleShowTokenUsage(show)
        }
    }
}

// MARK: - Private

private extension SettingsViewModel {
    func loadSettings() {
        let loadedState = LoadedState(
            serverURL: settingsManager.getServerBaseURL(),
            apiKey: settingsManager.getAPIKey(),
            isCloudSyncEnabled: settingsManager.getIsCloudSyncEnabled(),
            isCloudAvailable: cloudSyncManager.isCloudAvailable(),
            showTokenUsage: settingsManager.getShowTokenUsage()
        )
        state = .loaded(loadedState)
    }

    func updateServerURL(_ url: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.serverURL = url
        loadedState.connectionStatus = .idle
        loadedState.isSaved = false
        state = .loaded(loadedState)
    }

    func updateAPIKey(_ key: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.apiKey = key
        loadedState.connectionStatus = .idle
        loadedState.isSaved = false
        state = .loaded(loadedState)
    }

    func testConnection() {
        guard case .loaded(var loadedState) = state else { return }
        LogManager.info("testConnection url=\(loadedState.serverURL)")
        loadedState.connectionStatus = .testing
        state = .loaded(loadedState)

        Task {
            do {
                try await testServerConnectionUseCase.execute(
                    serverURL: loadedState.serverURL,
                    apiKey: loadedState.apiKey
                )
                guard case .loaded(var currentState) = state else { return }
                currentState.connectionStatus = .success
                state = .loaded(currentState)
                LogManager.success("testConnection success url=\(loadedState.serverURL)")
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.connectionStatus = .failure(error.localizedDescription)
                state = .loaded(currentState)
                LogManager.error("testConnection failed url=\(loadedState.serverURL): \(error)")
            }
        }
    }

    func saveSettings() {
        guard case .loaded(var loadedState) = state else { return }
        LogManager.info("saveSettings url=\(loadedState.serverURL)")
        saveServerConfigurationUseCase.execute(
            serverURL: loadedState.serverURL,
            apiKey: loadedState.apiKey
        )
        loadedState.isSaved = true
        state = .loaded(loadedState)
        LogManager.success("saveSettings done")
    }

    func toggleCloudSync(_ enabled: Bool) {
        guard case .loaded(var loadedState) = state else { return }

        if enabled {
            let localProfile = userProfileManager.getLocalProfile()
            let cloudProfile = userProfileManager.getCloudProfile()

            // Both local and cloud have non-empty profiles → ask user which to keep.
            if !localProfile.isEmpty, let cloud = cloudProfile, !cloud.isEmpty, localProfile != cloud {
                loadedState.showCloudSyncConflictAlert = true
                state = .loaded(loadedState)
                return
            }

            // Only local has data → push to cloud.
            settingsManager.setIsCloudSyncEnabled(true)
            loadedState.isCloudSyncEnabled = true
            state = .loaded(loadedState)

            if !localProfile.isEmpty && (cloudProfile?.isEmpty ?? true) {
                userProfileManager.resolveCloudSyncConflict(keepLocal: true)
            }
        } else {
            settingsManager.setIsCloudSyncEnabled(false)
            loadedState.isCloudSyncEnabled = false
            state = .loaded(loadedState)
        }
    }

    func resolveCloudSyncConflict(keepLocal: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        settingsManager.setIsCloudSyncEnabled(true)
        userProfileManager.resolveCloudSyncConflict(keepLocal: keepLocal)
        loadedState.isCloudSyncEnabled = true
        loadedState.showCloudSyncConflictAlert = false
        state = .loaded(loadedState)
    }

    func cancelCloudSyncToggle() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.showCloudSyncConflictAlert = false
        state = .loaded(loadedState)
    }

    func toggleShowTokenUsage(_ show: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        settingsManager.setShowTokenUsage(show)
        loadedState.showTokenUsage = show
        state = .loaded(loadedState)
    }
}
