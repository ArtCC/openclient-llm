//
//  ModelsViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ModelsViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case refreshTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var models: [LLMModel] = []
        var errorMessage: String?
        var isRefreshing: Bool = false
    }

    private(set) var state: State

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol

    // MARK: - Init

    init(
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase()
    ) {
        self.state = state
        self.fetchModelsUseCase = fetchModelsUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadModels()
        case .refreshTapped:
            refreshModels()
        }
    }
}

// MARK: - Private

private extension ModelsViewModel {
    func loadModels() {
        state = .loading

        Task {
            do {
                let models = try await fetchModelsUseCase.execute()
                state = .loaded(LoadedState(models: models))
            } catch {
                state = .loaded(LoadedState(errorMessage: error.localizedDescription))
            }
        }
    }

    func refreshModels() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isRefreshing = true
        loadedState.errorMessage = nil
        state = .loaded(loadedState)

        Task {
            do {
                let models = try await fetchModelsUseCase.execute()
                state = .loaded(LoadedState(models: models))
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.isRefreshing = false
                currentState.errorMessage = error.localizedDescription
                state = .loaded(currentState)
            }
        }
    }
}
