//
//  ChatViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ChatViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case inputChanged(String)
        case sendTapped
        case modelSelected(LLMModel)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var messages: [ChatMessage] = []
        var inputText: String = ""
        var isStreaming: Bool = false
        var selectedModel: LLMModel?
        var availableModels: [LLMModel] = []
        var errorMessage: String?
    }

    private(set) var state: State

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let streamMessageUseCase: StreamMessageUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.state = state
        self.fetchModelsUseCase = fetchModelsUseCase
        self.streamMessageUseCase = streamMessageUseCase
        self.settingsManager = settingsManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadInitialData()
        case .inputChanged(let text):
            updateInput(text)
        case .sendTapped:
            sendMessage()
        case .modelSelected(let model):
            selectModel(model)
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func loadInitialData() {
        state = .loading

        Task {
            do {
                let models = try await fetchModelsUseCase.execute()
                let savedModelId = settingsManager.getSelectedModelId()
                let selectedModel = models.first(where: { $0.id == savedModelId }) ?? models.first
                state = .loaded(LoadedState(
                    selectedModel: selectedModel,
                    availableModels: models
                ))
            } catch {
                state = .loaded(LoadedState(errorMessage: error.localizedDescription))
            }
        }
    }

    func updateInput(_ text: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.inputText = text
        state = .loaded(loadedState)
    }

    func selectModel(_ model: LLMModel) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedModel = model
        state = .loaded(loadedState)
        settingsManager.setSelectedModelId(model.id)
    }

    func sendMessage() {
        guard case .loaded(var loadedState) = state else { return }
        let text = loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let model = loadedState.selectedModel, !loadedState.isStreaming else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        loadedState.messages.append(userMessage)
        loadedState.inputText = ""
        loadedState.isStreaming = true
        loadedState.errorMessage = nil

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        loadedState.messages.append(assistantMessage)
        state = .loaded(loadedState)

        let assistantMessageId = assistantMessage.id
        let currentMessages = loadedState.messages.filter { $0.id != assistantMessageId }

        streamTask?.cancel()
        streamTask = Task {
            await performStreaming(messages: currentMessages, model: model.id, assistantMessageId: assistantMessageId)
        }
    }

    func performStreaming(messages: [ChatMessage], model: String, assistantMessageId: UUID) async {
        do {
            let stream = streamMessageUseCase.execute(messages: messages, model: model)
            for try await token in stream {
                guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
                if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    currentState.messages[index].content += token
                }
                state = .loaded(currentState)
            }

            guard case .loaded(var currentState) = state else { return }
            currentState.isStreaming = false
            state = .loaded(currentState)
        } catch {
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }),
               currentState.messages[index].content.isEmpty {
                currentState.messages.remove(at: index)
            }
            currentState.isStreaming = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
        }
    }
}
