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
        case modelParametersChanged(ModelParameters)
        case speakMessageTapped(ChatMessage)
        case stopSpeakingTapped
        case audioRecorded(Data, TimeInterval)
        case generateImageTapped
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
        var modelParameters: ModelParameters = .default
        var isSpeaking: Bool = false
        var speakingMessageId: UUID?
        var ttsModel: LLMModel?
        var transcriptionModel: LLMModel?
        var isTranscribing: Bool = false
        var imageModel: LLMModel?
        var isGeneratingImage: Bool = false
        var showTokenUsage: Bool = true
    }

    var state: State

    var onConversationUpdated: (() -> Void)?

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let streamMessageUseCase: StreamMessageUseCaseProtocol
    private let saveConversationUseCase: SaveConversationUseCaseProtocol
    private let synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol
    let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    let generateImageUseCase: GenerateImageUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol
    private let conversationStartersManager: ConversationStartersManagerProtocol
    private let audioPlayerManager: AudioPlayerManager
    private var streamTask: Task<Void, Never>?
    private var errorDismissTask: Task<Void, Never>?
    private var pendingConversation: Conversation?

    // MARK: - Init

    init(
        conversation: Conversation? = nil,
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase(),
        synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol = SynthesizeSpeechUseCase(),
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCase(),
        generateImageUseCase: GenerateImageUseCaseProtocol = GenerateImageUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationStartersManager: ConversationStartersManagerProtocol = ConversationStartersManager(),
        audioPlayerManager: AudioPlayerManager = AudioPlayerManager()
    ) {
        self.state = state
        self.pendingConversation = conversation
        self.fetchModelsUseCase = fetchModelsUseCase
        self.streamMessageUseCase = streamMessageUseCase
        self.saveConversationUseCase = saveConversationUseCase
        self.synthesizeSpeechUseCase = synthesizeSpeechUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.generateImageUseCase = generateImageUseCase
        self.settingsManager = settingsManager
        self.conversationStartersManager = conversationStartersManager
        self.audioPlayerManager = audioPlayerManager
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
        case .modelSelected,
             .systemPromptChanged,
             .attachmentAdded,
             .attachmentRemoved,
             .modelParametersChanged,
             .speakMessageTapped,
             .stopSpeakingTapped,
             .audioRecorded,
             .generateImageTapped:
            handleConfigurationEvent(event)
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func handleConfigurationEvent(_ event: Event) {
        switch event {
        case .modelSelected(let model): selectModel(model)
        case .systemPromptChanged(let prompt): updateSystemPrompt(prompt)
        case .attachmentAdded(let attachment): addAttachment(attachment)
        case .attachmentRemoved(let id): removeAttachment(id)
        case .modelParametersChanged(let parameters): updateModelParameters(parameters)
        case .speakMessageTapped(let message): speakMessage(message)
        case .stopSpeakingTapped: stopSpeaking()
        case .audioRecorded(let data, let duration): transcribeAudio(data: data, duration: duration)
        case .generateImageTapped: generateImage()
        default: break
        }
    }

    func loadInitialData() {
        state = .loading
        Task { await fetchAndBuildInitialState() }
    }

    func fetchAndBuildInitialState() async {
        do {
            let models = try await fetchModelsUseCase.execute()
            let pending = pendingConversation
            pendingConversation = nil

            let chatModels = models.filter { [.chat, .completion, .unknown].contains($0.mode) }
            let ttsModel = models.first { $0.mode == .audioSpeech }
            let transcriptionModel = models.first { $0.mode == .audioTranscription }
            let imageModel = models.first { $0.mode == .imageGeneration }
            let savedModelId = settingsManager.getSelectedModelId()
            let selectedModel: LLMModel?

            if let pending {
                selectedModel = chatModels.first(where: { $0.id == pending.modelId })
                    ?? chatModels.first(where: { $0.id == savedModelId })
                    ?? chatModels.first
            } else {
                selectedModel = chatModels.first(where: { $0.id == savedModelId }) ?? chatModels.first
            }

            let starters = conversationStartersManager.randomStarters(count: 4)
            state = .loaded(LoadedState(
                conversation: pending,
                messages: pending?.messages ?? [],
                selectedModel: selectedModel,
                availableModels: chatModels,
                conversationStarters: (pending?.messages ?? []).isEmpty ? starters : [],
                systemPrompt: pending?.systemPrompt ?? "",
                modelParameters: pending?.modelParameters ?? .default,
                ttsModel: ttsModel,
                transcriptionModel: transcriptionModel,
                imageModel: imageModel,
                showTokenUsage: settingsManager.getShowTokenUsage()
            ))
        } catch {
            let pending = pendingConversation
            pendingConversation = nil
            state = .loaded(LoadedState(
                conversation: pending,
                messages: pending?.messages ?? [],
                errorMessage: error.localizedDescription,
                systemPrompt: pending?.systemPrompt ?? "",
                modelParameters: pending?.modelParameters ?? .default
            ))
            scheduleErrorDismiss()
        }
    }

    func loadConversation(_ conversation: Conversation) {
        guard case .loaded(var loadedState) = state else {
            pendingConversation = conversation
            return
        }
        loadedState.conversation = conversation
        loadedState.messages = conversation.messages
        loadedState.systemPrompt = conversation.systemPrompt
        loadedState.modelParameters = conversation.modelParameters
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

    func updateModelParameters(_ parameters: ModelParameters) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.modelParameters = parameters
        if loadedState.conversation != nil {
            loadedState.conversation?.modelParameters = parameters
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
        let parameters = loadedState.modelParameters

        streamTask?.cancel()
        streamTask = Task {
            await performStreaming(
                messages: currentMessages,
                model: model.id,
                assistantMessageId: assistantMessageId,
                systemPrompt: systemPrompt,
                parameters: parameters
            )
        }
    }

    func performStreaming(
        messages: [ChatMessage],
        model: String,
        assistantMessageId: UUID,
        systemPrompt: String,
        parameters: ModelParameters
    ) async {
        // Build messages with system prompt prepended
        var allMessages = messages
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let systemMessage = ChatMessage(role: .system, content: systemPrompt)
            allMessages.insert(systemMessage, at: 0)
        }

        do {
            let stream = streamMessageUseCase.execute(messages: allMessages, model: model, parameters: parameters)
            for try await chunk in stream {
                guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
                applyStreamChunk(chunk, to: &currentState, assistantMessageId: assistantMessageId)
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
            scheduleErrorDismiss()
            persistConversation()
        }
    }

    func applyStreamChunk(
        _ chunk: StreamChunk,
        to state: inout LoadedState,
        assistantMessageId: UUID
    ) {
        switch chunk {
        case .token(let token):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].content += token
            }
        case .usage(let usage):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].tokenUsage = usage
            }
        }
    }

    func speakMessage(_ message: ChatMessage) {
        guard case .loaded(var loadedState) = state,
              !message.content.isEmpty else { return }
        guard let ttsModel = loadedState.ttsModel else {
            loadedState.errorMessage = String(
                localized: "No text-to-speech models available. Add a TTS model like tts-1 to your LiteLLM server."
            )
            state = .loaded(loadedState)
            scheduleErrorDismiss()
            return
        }

        loadedState.isSpeaking = true
        loadedState.speakingMessageId = message.id
        state = .loaded(loadedState)
        Task {
            do {
                let audioData = try await synthesizeSpeechUseCase.execute(
                    text: message.content,
                    model: ttsModel.id,
                    voice: "alloy"
                )
                audioPlayerManager.play(data: audioData, messageId: message.id)
                Task {
                    while audioPlayerManager.isPlaying {
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                    guard case .loaded(var currentState) = state else { return }
                    currentState.isSpeaking = false
                    currentState.speakingMessageId = nil
                    state = .loaded(currentState)
                }
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.isSpeaking = false
                currentState.speakingMessageId = nil
                currentState.errorMessage = error.localizedDescription
                state = .loaded(currentState)
                scheduleErrorDismiss()
            }
        }
    }

    func stopSpeaking() {
        audioPlayerManager.stop()
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isSpeaking = false
        loadedState.speakingMessageId = nil
        state = .loaded(loadedState)
    }

}

// MARK: - Internal helpers

extension ChatViewModel {
    func persistConversation() {
        guard case .loaded(let loadedState) = state,
              var conversation = loadedState.conversation else { return }

        conversation.messages = loadedState.messages
        conversation.systemPrompt = loadedState.systemPrompt
        conversation.modelParameters = loadedState.modelParameters
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

    func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            currentState.errorMessage = nil
            state = .loaded(currentState)
        }
    }
}
