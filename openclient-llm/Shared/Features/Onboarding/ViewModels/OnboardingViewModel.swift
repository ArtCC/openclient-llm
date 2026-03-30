//
//  OnboardingViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class OnboardingViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case getStartedTapped
        case backTapped
        case skipTapped
        case serverURLChanged(String)
        case apiKeyChanged(String)
        case testConnectionTapped
        case nextTapped
        case startChattingTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var currentStep: OnboardingStep = .welcome
        var serverURL: String = ""
        var apiKey: String = ""
        var connectionStatus: ConnectionStatus = .idle
    }

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    private(set) var state: State

    var onComplete: (() -> Void)?

    private let completeOnboardingUseCase: CompleteOnboardingUseCaseProtocol
    private let saveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol
    private let testServerConnectionUseCase: TestServerConnectionUseCaseProtocol

    // MARK: - Init

    init(
        state: State = .loading,
        completeOnboardingUseCase: CompleteOnboardingUseCaseProtocol = CompleteOnboardingUseCase(),
        saveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol = SaveServerConfigurationUseCase(),
        testServerConnectionUseCase: TestServerConnectionUseCaseProtocol = TestServerConnectionUseCase()
    ) {
        self.state = state
        self.completeOnboardingUseCase = completeOnboardingUseCase
        self.saveServerConfigurationUseCase = saveServerConfigurationUseCase
        self.testServerConnectionUseCase = testServerConnectionUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            state = .loaded(LoadedState())
        case .getStartedTapped:
            updateStep(.serverConfiguration)
        case .backTapped:
            handleBack()
        case .skipTapped:
            handleSkip()
        case .serverURLChanged(let url):
            updateServerURL(url)
        case .apiKeyChanged(let key):
            updateAPIKey(key)
        case .testConnectionTapped:
            testConnection()
        case .nextTapped:
            updateStep(.allSet)
        case .startChattingTapped:
            handleComplete()
        }
    }
}

// MARK: - Private

private extension OnboardingViewModel {
    func updateStep(_ step: OnboardingStep) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.currentStep = step
        state = .loaded(loadedState)
    }

    func handleBack() {
        guard case .loaded(var loadedState) = state else { return }
        switch loadedState.currentStep {
        case .welcome:
            break
        case .serverConfiguration:
            loadedState.currentStep = .welcome
            state = .loaded(loadedState)
        case .allSet:
            loadedState.currentStep = .serverConfiguration
            state = .loaded(loadedState)
        }
    }

    func handleSkip() {
        completeOnboardingUseCase.execute()
        onComplete?()
    }

    func updateServerURL(_ url: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.serverURL = url
        loadedState.connectionStatus = .idle
        state = .loaded(loadedState)
    }

    func updateAPIKey(_ key: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.apiKey = key
        loadedState.connectionStatus = .idle
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

    func handleComplete() {
        guard case .loaded(let loadedState) = state else { return }
        saveServerConfigurationUseCase.execute(
            serverURL: loadedState.serverURL,
            apiKey: loadedState.apiKey
        )
        completeOnboardingUseCase.execute()
        onComplete?()
    }
}
