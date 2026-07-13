//
//  EphemeralChatViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class EphemeralChatViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case viewDisappeared
        case inputChanged(String)
        case modelSelected(LLMModel)
        case attachmentAdded(data: Data, fileName: String, type: ChatMessage.AttachmentType)
        case attachmentRemoved(UUID)
        case agentToggled
        case webSearchToggled
        case sendTapped
        case stopStreamingTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var messages: [ChatMessage] = []
        var inputText: String = ""
        var pendingAttachments: [ChatMessage.Attachment] = []
        var isStreaming: Bool = false
        var isSearchingWeb: Bool = false
        var selectedModel: LLMModel?
        var availableModels: [LLMModel] = []
        var isAgentEnabled: Bool = false
        var isWebSearchEnabled: Bool = false
        var isWebSearchToolConfigured: Bool = false
        var errorMessage: String?
    }

    private(set) var state: State

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let streamMessageUseCase: StreamMessageUseCaseProtocol
    private let agentStreamUseCase: AgentStreamUseCaseProtocol
    private let webSearchUseCase: WebSearchUseCaseProtocol
    private let getChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol
    private var streamTask: Task<Void, Never>?
    private var activeAssistantMessageId: UUID?
    private var activeWebSearchToolCallIDs: Set<String> = []

    // MARK: - Init

    init(
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        agentStreamUseCase: AgentStreamUseCaseProtocol = AgentStreamUseCase(),
        webSearchUseCase: WebSearchUseCaseProtocol = WebSearchUseCase(),
        getChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol = GetChatPreferencesUseCase()
    ) {
        self.state = state
        self.fetchModelsUseCase = fetchModelsUseCase
        self.streamMessageUseCase = streamMessageUseCase
        self.agentStreamUseCase = agentStreamUseCase
        self.webSearchUseCase = webSearchUseCase
        self.getChatPreferencesUseCase = getChatPreferencesUseCase
    }

    // MARK: - Public

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadModels()
        case .viewDisappeared:
            discardSession()
        case .inputChanged(let text):
            updateInput(text)
        case .modelSelected(let model):
            selectModel(model)
        case .attachmentAdded(let data, let fileName, let type):
            addAttachment(data: data, fileName: fileName, type: type)
        case .attachmentRemoved(let id):
            removeAttachment(id: id)
        case .agentToggled:
            toggleAgent()
        case .webSearchToggled:
            toggleWebSearch()
        case .sendTapped:
            sendMessage()
        case .stopStreamingTapped:
            cancelStreaming()
        }
    }
}

// MARK: - Private

private extension EphemeralChatViewModel {
    func loadModels() {
        state = .loading
        Task {
            do {
                let models = try await fetchModelsUseCase.execute().filter {
                    [.chat, .completion, .unknown, .imageGeneration].contains($0.mode)
                }
                let selectedID = getChatPreferencesUseCase.getSelectedModelId()
                state = .loaded(LoadedState(
                    selectedModel: models.first(where: { $0.id == selectedID }) ?? models.first,
                    availableModels: models,
                    isWebSearchToolConfigured: !getChatPreferencesUseCase.getWebSearchToolName().isEmpty
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
        if !model.capabilities.contains(.functionCalling) {
            loadedState.isAgentEnabled = false
            loadedState.isWebSearchEnabled = false
        }
        state = .loaded(loadedState)
    }

    func addAttachment(data: Data, fileName: String, type: ChatMessage.AttachmentType) {
        guard case .loaded(var loadedState) = state else { return }
        let attachment = ChatMessage.Attachment(
            type: type,
            fileName: fileName,
            mimeType: ChatMessage.Attachment.inferMimeType(for: type, fileName: fileName),
            fileRelativePath: "",
            transientData: data
        )
        loadedState.pendingAttachments.append(attachment)
        state = .loaded(loadedState)
    }

    func removeAttachment(id: UUID) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.pendingAttachments.removeAll { $0.id == id }
        state = .loaded(loadedState)
    }

    func toggleWebSearch() {
        guard case .loaded(var loadedState) = state else { return }
        guard loadedState.isAgentEnabled,
              loadedState.selectedModel?.capabilities.contains(.functionCalling) == true else { return }
        loadedState.isWebSearchEnabled.toggle()
        state = .loaded(loadedState)
    }

    func toggleAgent() {
        guard case .loaded(var loadedState) = state,
              loadedState.selectedModel?.capabilities.contains(.functionCalling) == true else { return }
        loadedState.isAgentEnabled.toggle()
        if !loadedState.isAgentEnabled {
            loadedState.isWebSearchEnabled = false
        }
        state = .loaded(loadedState)
    }

    func sendMessage() {
        guard case .loaded(var loadedState) = state,
              let model = loadedState.selectedModel,
              !loadedState.isStreaming else { return }
        let text = loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !loadedState.pendingAttachments.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text, attachments: loadedState.pendingAttachments)
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        loadedState.messages.append(userMessage)
        loadedState.messages.append(assistantMessage)
        loadedState.inputText = ""
        loadedState.pendingAttachments = []
        loadedState.isStreaming = true
        loadedState.errorMessage = nil
        state = .loaded(loadedState)
        activeAssistantMessageId = assistantMessage.id
        startStreaming(messages: loadedState.messages, model: model, assistantID: assistantMessage.id)
    }

    func startStreaming(messages: [ChatMessage], model: LLMModel, assistantID: UUID) {
        let requestMessages = Array(messages.dropLast().suffix(50))
        let agentEnabled = isAgentEnabled
        let webSearchEnabled = isWebSearchEnabled
        streamTask?.cancel()
        streamTask = Task {
            if model.capabilities.contains(.functionCalling), agentEnabled {
                await performAgentStreaming(
                    requestMessages,
                    model: model,
                    assistantID: assistantID,
                    webSearchEnabled: webSearchEnabled
                )
            } else {
                await performStreaming(requestMessages, model: model, assistantID: assistantID)
            }
        }
    }

    var isWebSearchEnabled: Bool {
        guard case .loaded(let loadedState) = state else { return false }
        return loadedState.isWebSearchEnabled
    }

    var isAgentEnabled: Bool {
        guard case .loaded(let loadedState) = state else { return false }
        return loadedState.isAgentEnabled
    }

    func performStreaming(_ messages: [ChatMessage], model: LLMModel, assistantID: UUID) async {
        let stream = streamMessageUseCase.execute(messages: messages, model: model.id, parameters: .default)
        do {
            for try await chunk in stream {
                guard isActiveStream(assistantID) else { return }
                applyStreamChunk(chunk, assistantID: assistantID)
            }
            finishStreaming(assistantID: assistantID)
        } catch {
            failStreaming(error, assistantID: assistantID)
        }
    }

    func performAgentStreaming(
        _ messages: [ChatMessage],
        model: LLMModel,
        assistantID: UUID,
        webSearchEnabled: Bool
    ) async {
        let registry = ToolRegistry.default(
            webSearchEnabled: webSearchEnabled,
            includesMemoryTools: false,
            webSearchUseCase: webSearchUseCase
        )
        let stream = agentStreamUseCase.execute(
            messages: messages,
            model: model.id,
            parameters: .default,
            toolRegistry: registry
        )
        do {
            for try await event in stream {
                guard isActiveStream(assistantID) else { return }
                applyAgentEvent(event, assistantID: assistantID)
            }
            finishStreaming(assistantID: assistantID)
        } catch {
            failStreaming(error, assistantID: assistantID)
        }
    }

    func applyStreamChunk(_ chunk: StreamChunk, assistantID: UUID) {
        switch chunk {
        case .token(let text): updateAssistant(assistantID) { $0.content += text }
        case .reasoning(let text):
            updateAssistant(assistantID) { $0.reasoningContent = ($0.reasoningContent ?? "") + text }
        case .usage(let usage): updateAssistant(assistantID) { $0.tokenUsage = usage }
        case .image(let data): appendGeneratedImage(data, assistantID: assistantID)
        }
    }

    func applyAgentEvent(_ event: AgentEvent, assistantID: UUID) {
        switch event {
        case .token(let text): updateAssistant(assistantID) { $0.content += text }
        case .reasoning(let text):
            updateAssistant(assistantID) { $0.reasoningContent = ($0.reasoningContent ?? "") + text }
        case .usage(let usage): updateAssistant(assistantID) { $0.tokenUsage = usage }
        case .image(let data): appendGeneratedImage(data, assistantID: assistantID)
        case .toolCallStarted(let toolCall):
            handleToolCallStarted(toolCall)
        case .toolCallCompleted(let toolCallID, _, let results):
            handleToolCallCompleted(toolCallID)
            appendSearchResults(results, assistantID: assistantID)
        case .completed: break
        }
    }

    func updateAssistant(_ id: UUID, update: (inout ChatMessage) -> Void) {
        guard case .loaded(var loadedState) = state,
              let index = loadedState.messages.firstIndex(where: { $0.id == id }) else { return }
        update(&loadedState.messages[index])
        state = .loaded(loadedState)
    }

    func appendGeneratedImage(_ data: Data, assistantID: UUID) {
        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: String(localized: "Generated Image"),
            mimeType: "image/png",
            fileRelativePath: "",
            transientData: data
        )
        updateAssistant(assistantID) { $0.attachments.append(attachment) }
    }

    func updateSearchState(_ isSearching: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isSearchingWeb = isSearching
        state = .loaded(loadedState)
    }

    func handleToolCallStarted(_ toolCall: ToolCall) {
        guard toolCall.function.name == "web_search" else { return }
        activeWebSearchToolCallIDs.insert(toolCall.id)
        updateSearchState(true)
    }

    func handleToolCallCompleted(_ toolCallID: String) {
        activeWebSearchToolCallIDs.remove(toolCallID)
        updateSearchState(!activeWebSearchToolCallIDs.isEmpty)
    }

    func appendSearchResults(_ results: [LiteLLMSearchResult]?, assistantID: UUID) {
        guard let results, !results.isEmpty else { return }
        updateAssistant(assistantID) { $0.webSearchResults = ($0.webSearchResults ?? []) + results }
    }

    func finishStreaming(assistantID: UUID) {
        guard isActiveStream(assistantID), case .loaded(var loadedState) = state else { return }
        loadedState.isStreaming = false
        loadedState.isSearchingWeb = false
        state = .loaded(loadedState)
        activeAssistantMessageId = nil
        activeWebSearchToolCallIDs.removeAll()
        streamTask = nil
    }

    func failStreaming(_ error: Error, assistantID: UUID) {
        guard isActiveStream(assistantID), case .loaded(var loadedState) = state else { return }
        loadedState.isStreaming = false
        loadedState.isSearchingWeb = false
        loadedState.errorMessage = error.localizedDescription
        state = .loaded(loadedState)
        activeAssistantMessageId = nil
        activeWebSearchToolCallIDs.removeAll()
        streamTask = nil
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        activeAssistantMessageId = nil
        activeWebSearchToolCallIDs.removeAll()
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isStreaming = false
        loadedState.isSearchingWeb = false
        state = .loaded(loadedState)
    }

    func discardSession() {
        cancelStreaming()
        state = .loaded(LoadedState())
    }

    func isActiveStream(_ assistantID: UUID) -> Bool {
        activeAssistantMessageId == assistantID && !Task.isCancelled
    }
}
