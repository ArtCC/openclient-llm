//
//  ConversationListViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ConversationListViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case newConversationTapped
        case conversationTapped(Conversation)
        case deleteConversation(UUID)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var conversations: [Conversation] = []
        var selectedConversation: Conversation?
        var availableModels: [LLMModel] = []
        var errorMessage: String?
    }

    private(set) var state: State

    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol
    private let deleteConversationUseCase: DeleteConversationUseCaseProtocol
    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol

    var onConversationSelected: ((Conversation?) -> Void)?

    // MARK: - Init

    init(
        state: State = .loading,
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        deleteConversationUseCase: DeleteConversationUseCaseProtocol = DeleteConversationUseCase(),
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.state = state
        self.loadConversationsUseCase = loadConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.settingsManager = settingsManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadData()
        case .newConversationTapped:
            createNewConversation()
        case .conversationTapped(let conversation):
            selectConversation(conversation)
        case .deleteConversation(let id):
            deleteConversation(id)
        }
    }

    func refresh() {
        reloadConversations()
    }
}

// MARK: - Private

private extension ConversationListViewModel {
    func loadData() {
        state = .loading

        Task {
            var models: [LLMModel] = []
            do {
                models = try await fetchModelsUseCase.execute()
            } catch {
                // Continue with empty models — user can still view conversations
            }

            do {
                let conversations = try loadConversationsUseCase.execute()
                state = .loaded(LoadedState(
                    conversations: conversations,
                    availableModels: models
                ))
            } catch {
                state = .loaded(LoadedState(
                    availableModels: models,
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    func reloadConversations() {
        guard case .loaded(var loadedState) = state else { return }

        do {
            loadedState.conversations = try loadConversationsUseCase.execute()
            loadedState.errorMessage = nil
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
        }
    }

    func createNewConversation() {
        guard case .loaded(let loadedState) = state else { return }

        let savedModelId = settingsManager.getSelectedModelId()
        let modelId = loadedState.availableModels.first(where: { $0.id == savedModelId })?.id
            ?? loadedState.availableModels.first?.id
            ?? savedModelId
            ?? ""

        let conversation = Conversation(modelId: modelId)
        onConversationSelected?(conversation)
    }

    func selectConversation(_ conversation: Conversation) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedConversation = conversation
        state = .loaded(loadedState)
        onConversationSelected?(conversation)
    }

    func deleteConversation(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }

        do {
            try deleteConversationUseCase.execute(id)
            loadedState.conversations.removeAll { $0.id == id }
            if loadedState.selectedConversation?.id == id {
                loadedState.selectedConversation = nil
                onConversationSelected?(nil)
            }
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
        }
    }
}
