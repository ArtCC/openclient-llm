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
        case conversationLoaded(Conversation)
        case inputChanged(String)
        case sendTapped
        case stopStreamingTapped
        case suggestionTapped(String)
        case modelSelected(LLMModel)
        case systemPromptChanged(String)
        case attachmentAdded(ChatMessage.Attachment)
        case attachmentRemoved(UUID)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var conversation: Conversation?
        var messages: [ChatMessage] = []
        var inputText: String = ""
        var isStreaming: Bool = false
        var selectedModel: LLMModel?
        var availableModels: [LLMModel] = []
        var conversationStarters: [ConversationStarter] = []
        var errorMessage: String?
        var systemPrompt: String = ""
        var pendingAttachments: [ChatMessage.Attachment] = []
    }

    private(set) var state: State

    var onConversationUpdated: (() -> Void)?

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let streamMessageUseCase: StreamMessageUseCaseProtocol
    private let saveConversationUseCase: SaveConversationUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol
    private let conversationStartersManager: ConversationStartersManagerProtocol
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationStartersManager: ConversationStartersManagerProtocol = ConversationStartersManager()
    ) {
        self.state = state
        self.fetchModelsUseCase = fetchModelsUseCase
        self.streamMessageUseCase = streamMessageUseCase
        self.saveConversationUseCase = saveConversationUseCase
        self.settingsManager = settingsManager
        self.conversationStartersManager = conversationStartersManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadInitialData()
        case .conversationLoaded(let conversation):
            loadConversation(conversation)
        case .inputChanged(let text):
            updateInput(text)
        case .sendTapped:
            sendMessage()
        case .stopStreamingTapped:
            stopStreaming()
        case .suggestionTapped(let prompt):
            handleSuggestionTapped(prompt)
        case .modelSelected(let model):
            selectModel(model)
        case .systemPromptChanged(let prompt):
            updateSystemPrompt(prompt)
        case .attachmentAdded(let attachment):
            addAttachment(attachment)
        case .attachmentRemoved(let id):
            removeAttachment(id)
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
                let starters = conversationStartersManager.randomStarters(count: 4)
                state = .loaded(LoadedState(
                    selectedModel: selectedModel,
                    availableModels: models,
                    conversationStarters: starters
                ))
            } catch {
                state = .loaded(LoadedState(errorMessage: error.localizedDescription))
            }
        }
    }

    func loadConversation(_ conversation: Conversation) {
        guard case .loaded(var loadedState) = state else {
            // If still loading, wait for initial data then load conversation
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard case .loaded(var loadedState) = state else { return }
                loadedState.conversation = conversation
                loadedState.messages = conversation.messages
                loadedState.systemPrompt = conversation.systemPrompt
                let selectedModel = loadedState.availableModels.first(where: { $0.id == conversation.modelId })
                    ?? loadedState.selectedModel
                loadedState.selectedModel = selectedModel
                state = .loaded(loadedState)
            }
            return
        }
        loadedState.conversation = conversation
        loadedState.messages = conversation.messages
        loadedState.systemPrompt = conversation.systemPrompt
        let selectedModel = loadedState.availableModels.first(where: { $0.id == conversation.modelId })
            ?? loadedState.selectedModel
        loadedState.selectedModel = selectedModel
        loadedState.pendingAttachments = []
        loadedState.inputText = ""
        loadedState.errorMessage = nil
        state = .loaded(loadedState)
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

        if loadedState.conversation != nil {
            loadedState.conversation?.modelId = model.id
            state = .loaded(loadedState)
            persistConversation()
        }
    }

    func updateSystemPrompt(_ prompt: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.systemPrompt = prompt
        if loadedState.conversation != nil {
            loadedState.conversation?.systemPrompt = prompt
        }
        state = .loaded(loadedState)
        persistConversation()
    }

    func addAttachment(_ attachment: ChatMessage.Attachment) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.pendingAttachments.append(attachment)
        state = .loaded(loadedState)
    }

    func removeAttachment(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.pendingAttachments.removeAll { $0.id == id }
        state = .loaded(loadedState)
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isStreaming = false
        state = .loaded(loadedState)
        persistConversation()
    }

    func handleSuggestionTapped(_ prompt: String) {
        updateInput(prompt)
        sendMessage()
    }

    func sendMessage() {
        guard case .loaded(var loadedState) = state else { return }
        let text = loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let model = loadedState.selectedModel, !loadedState.isStreaming else { return }

        // Create or update conversation
        if loadedState.conversation == nil {
            loadedState.conversation = Conversation(modelId: model.id, systemPrompt: loadedState.systemPrompt)
        }

        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: loadedState.pendingAttachments
        )
        loadedState.messages.append(userMessage)
        loadedState.inputText = ""
        loadedState.pendingAttachments = []
        loadedState.isStreaming = true
        loadedState.errorMessage = nil

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        loadedState.messages.append(assistantMessage)
        state = .loaded(loadedState)

        // Auto-generate title from first user message
        if loadedState.conversation?.title.isEmpty == true {
            let preview = String(text.prefix(50))
            loadedState.conversation?.title = preview
            state = .loaded(loadedState)
        }

        let assistantMessageId = assistantMessage.id
        let currentMessages = loadedState.messages.filter { $0.id != assistantMessageId }
        let systemPrompt = loadedState.systemPrompt

        streamTask?.cancel()
        streamTask = Task {
            await performStreaming(
                messages: currentMessages,
                model: model.id,
                assistantMessageId: assistantMessageId,
                systemPrompt: systemPrompt
            )
        }
    }

    func performStreaming(
        messages: [ChatMessage],
        model: String,
        assistantMessageId: UUID,
        systemPrompt: String
    ) async {
        // Build messages with system prompt prepended
        var allMessages = messages
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let systemMessage = ChatMessage(role: .system, content: systemPrompt)
            allMessages.insert(systemMessage, at: 0)
        }

        do {
            let stream = streamMessageUseCase.execute(messages: allMessages, model: model)
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
            persistConversation()
        } catch {
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }),
               currentState.messages[index].content.isEmpty {
                currentState.messages.remove(at: index)
            }
            currentState.isStreaming = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            persistConversation()
        }
    }

    func persistConversation() {
        guard case .loaded(let loadedState) = state,
              var conversation = loadedState.conversation else { return }

        conversation.messages = loadedState.messages
        conversation.systemPrompt = loadedState.systemPrompt
        conversation.updatedAt = Date()
        if let model = loadedState.selectedModel {
            conversation.modelId = model.id
        }

        do {
            try saveConversationUseCase.execute(conversation)
            onConversationUpdated?()
        } catch {
            // Silently fail — persistence is best-effort
        }
    }
}
