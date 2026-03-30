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

    // MARK: - Init

    init(
        state: State = .loading,
        saveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol = SaveServerConfigurationUseCase(),
        testServerConnectionUseCase: TestServerConnectionUseCaseProtocol = TestServerConnectionUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.state = state
        self.saveServerConfigurationUseCase = saveServerConfigurationUseCase
        self.testServerConnectionUseCase = testServerConnectionUseCase
        self.settingsManager = settingsManager
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
        }
    }
}

// MARK: - Private

private extension SettingsViewModel {
    func loadSettings() {
        let loadedState = LoadedState(
            serverURL: settingsManager.getServerBaseURL(),
            apiKey: settingsManager.getAPIKey()
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
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.connectionStatus = .failure(error.localizedDescription)
                state = .loaded(currentState)
            }
        }
    }

    func saveSettings() {
        guard case .loaded(var loadedState) = state else { return }
        saveServerConfigurationUseCase.execute(
            serverURL: loadedState.serverURL,
            apiKey: loadedState.apiKey
        )
        loadedState.isSaved = true
        state = .loaded(loadedState)
    }
}
