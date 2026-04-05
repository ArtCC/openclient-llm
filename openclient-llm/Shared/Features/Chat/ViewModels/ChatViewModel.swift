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
        case startRecordingTapped
        case stopRecordingTapped
        case cancelRecordingTapped
        case exportConversation
        case exportDataConsumed
        case regenerateLastResponse
        case editMessage(id: UUID, newContent: String)
        case forkFromMessage(UUID)
        case branchedConversationConsumed
        case webSearchToggled
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
        var isRecording: Bool = false
        var recordingDuration: TimeInterval = 0
        var isTranscribing: Bool = false
        var showTokenUsage: Bool = true
        var scrollToBottomTrigger: Bool = false
        var ttsModelId: String?
        var transcriptionModelId: String?
        var exportedData: Data?
        var branchedConversation: Conversation?
        var isWebSearchEnabled: Bool = false
        var isSearchingWeb: Bool = false
    }

    var state: State

    var onConversationUpdated: (() -> Void)?
    var onForkCreated: ((Conversation) -> Void)?

    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    let streamMessageUseCase: StreamMessageUseCaseProtocol
    let agentStreamUseCase: AgentStreamUseCaseProtocol
    let webSearchUseCase: WebSearchUseCaseProtocol
    let saveConversationUseCase: SaveConversationUseCaseProtocol
    private let synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol
    let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    let exportConversationUseCase: ExportConversationUseCaseProtocol
    let branchConversationUseCase: BranchConversationUseCaseProtocol
    let settingsManager: SettingsManagerProtocol
    let userProfileManager: UserProfileManagerProtocol
    private let conversationStartersManager: ConversationStartersManagerProtocol
    private let audioPlayerManager: AudioPlayerManager
    let audioRecorderManager: AudioRecorderManagerProtocol
    var streamTask: Task<Void, Never>?
    var errorDismissTask: Task<Void, Never>?
    var durationTrackingTask: Task<Void, Never>?
    private var pendingConversation: Conversation?

    // MARK: - Init

    init(
        conversation: Conversation? = nil,
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        agentStreamUseCase: AgentStreamUseCaseProtocol = AgentStreamUseCase(),
        webSearchUseCase: WebSearchUseCaseProtocol = WebSearchUseCase(),
        saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase(),
        synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol = SynthesizeSpeechUseCase(),
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCase(),
        exportConversationUseCase: ExportConversationUseCaseProtocol = ExportConversationUseCase(),
        branchConversationUseCase: BranchConversationUseCaseProtocol = BranchConversationUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        conversationStartersManager: ConversationStartersManagerProtocol = ConversationStartersManager(),
        audioPlayerManager: AudioPlayerManager = AudioPlayerManager(),
        audioRecorderManager: AudioRecorderManagerProtocol = AudioRecorderManager()
    ) {
        self.state = state
        self.pendingConversation = conversation
        self.fetchModelsUseCase = fetchModelsUseCase
        self.streamMessageUseCase = streamMessageUseCase
        self.agentStreamUseCase = agentStreamUseCase
        self.webSearchUseCase = webSearchUseCase
        self.saveConversationUseCase = saveConversationUseCase
        self.synthesizeSpeechUseCase = synthesizeSpeechUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.exportConversationUseCase = exportConversationUseCase
        self.branchConversationUseCase = branchConversationUseCase
        self.settingsManager = settingsManager
        self.userProfileManager = userProfileManager
        self.conversationStartersManager = conversationStartersManager
        self.audioPlayerManager = audioPlayerManager
        self.audioRecorderManager = audioRecorderManager
        observeAppDataReset()
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
             .stopSpeakingTapped:
            handleConfigurationEvent(event)
        case .startRecordingTapped, .stopRecordingTapped, .cancelRecordingTapped:
            handleRecordingEvent(event)
        case .exportConversation, .exportDataConsumed, .regenerateLastResponse,
             .editMessage, .forkFromMessage, .branchedConversationConsumed:
            handlePhase6Event(event)
        case .webSearchToggled:
            toggleWebSearch()
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
        default: break
        }
    }

    func loadInitialData() {
        state = .loading
        Task { await fetchAndBuildInitialState() }
    }

    func fetchAndBuildInitialState() async {
        do {
            LogManager.debug("fetchAndBuildInitialState start")
            let models = try await fetchModelsUseCase.execute()
            let pending = pendingConversation
            pendingConversation = nil

            let chatModels = models.filter {
                [.chat, .completion, .unknown, .imageGeneration].contains($0.mode)
            }
            let savedModelId = settingsManager.getSelectedModelId()
            let selectedModel: LLMModel?

            if let pending {
                selectedModel = chatModels.first(where: { $0.id == pending.modelId })
                    ?? chatModels.first(where: { $0.id == savedModelId })
                    ?? chatModels.first
            } else {
                selectedModel = chatModels.first(where: { $0.id == savedModelId }) ?? chatModels.first
            }
            let selectedId = selectedModel?.id ?? "-"
            LogManager.success("fetchAndBuildInitialState models=\(chatModels.count) selected=\(selectedId)")

            let (ttsModelId, transcriptionModelId) = resolveAudioModelIds(from: models)
            let starters = conversationStartersManager.randomStarters(count: 4)
            state = .loaded(LoadedState(
                conversation: pending,
                messages: pending?.messages ?? [],
                selectedModel: selectedModel,
                availableModels: chatModels,
                conversationStarters: (pending?.messages ?? []).isEmpty ? starters : [],
                systemPrompt: pending?.systemPrompt ?? "",
                modelParameters: pending?.modelParameters ?? .default,
                showTokenUsage: settingsManager.getShowTokenUsage(),
                ttsModelId: ttsModelId,
                transcriptionModelId: transcriptionModelId,
                isWebSearchEnabled: settingsManager.getIsWebSearchEnabled()
            ))
        } catch {
            LogManager.error("fetchAndBuildInitialState failed: \(error)")
            let pending = pendingConversation
            pendingConversation = nil
            state = .loaded(LoadedState(
                conversation: pending,
                messages: pending?.messages ?? [],
                errorMessage: error.localizedDescription,
                systemPrompt: pending?.systemPrompt ?? "",
                modelParameters: pending?.modelParameters ?? .default,
                isWebSearchEnabled: settingsManager.getIsWebSearchEnabled()
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
        if !conversation.messages.isEmpty {
            loadedState.scrollToBottomTrigger.toggle()
        }
        state = .loaded(loadedState)
    }

    func updateInput(_ text: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.inputText = text
        state = .loaded(loadedState)
    }

    func selectModel(_ model: LLMModel) {
        guard case .loaded(var loadedState) = state else { return }
        LogManager.info("selectModel id=\(model.id)")
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
        LogManager.debug("stopStreaming requested")
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
        LogManager.info("sendMessage model=\(model.id) text=\"\(String(text.prefix(80)))\"")

        let assistantId = prepareMessageState(text: text, model: model, loadedState: &loadedState)
        let currentMessages = loadedState.messages.filter { $0.id != assistantId }
        let systemPrompt = loadedState.systemPrompt
        let parameters = loadedState.modelParameters
        let webSearchEnabled = loadedState.isWebSearchEnabled
        let modelCapabilities = model.capabilities
        let queryText = text

        streamTask?.cancel()
        streamTask = Task {
            let supportsAgentMode = webSearchEnabled && modelCapabilities.contains(.functionCalling)
            if supportsAgentMode {
                await performAgentStreaming(
                    messages: currentMessages,
                    model: model.id,
                    assistantMessageId: assistantId,
                    systemPrompt: systemPrompt,
                    parameters: parameters
                )
            } else {
                let searchResults = webSearchEnabled ? await fetchSearchResults(for: queryText) : []
                await performStreaming(
                    messages: currentMessages,
                    model: model.id,
                    assistantMessageId: assistantId,
                    systemPrompt: systemPrompt,
                    parameters: parameters,
                    searchResults: searchResults
                )
            }
        }
    }

    func prepareMessageState(text: String, model: LLMModel, loadedState: inout LoadedState) -> UUID {
        if loadedState.conversation == nil {
            loadedState.conversation = Conversation(modelId: model.id, systemPrompt: loadedState.systemPrompt)
        }
        let userMessage = ChatMessage(role: .user, content: text, attachments: loadedState.pendingAttachments)
        loadedState.messages.append(userMessage)
        loadedState.inputText = ""
        loadedState.pendingAttachments = []
        loadedState.isStreaming = true
        loadedState.errorMessage = nil
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        loadedState.messages.append(assistantMessage)
        if loadedState.conversation?.title.isEmpty == true {
            loadedState.conversation?.title = String(text.prefix(50))
        }
        state = .loaded(loadedState)
        return assistantMessage.id
    }

    func speakMessage(_ message: ChatMessage) {
        guard case .loaded(var loadedState) = state,
              !message.content.isEmpty else { return }
        guard let ttsModelId = loadedState.ttsModelId else { return }

        loadedState.isSpeaking = true
        loadedState.speakingMessageId = message.id
        state = .loaded(loadedState)
        Task {
            do {
                let audioData = try await synthesizeSpeechUseCase.execute(
                    text: message.content,
                    model: ttsModelId,
                    voice: settingsManager.getSelectedTTSVoice(forModelId: ttsModelId)
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

    func observeAppDataReset() {
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .appDataDidReset)
            for await _ in notifications {
                guard let self else { return }
                await MainActor.run { self.loadInitialData() }
            }
        }
    }
}
