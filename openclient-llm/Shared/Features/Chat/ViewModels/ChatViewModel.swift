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
        case attachmentAdded(data: Data, fileName: String, type: ChatMessage.AttachmentType)
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
        case toggleFavourite(UUID)
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
        var pendingSessionId: UUID = UUID()
        var modelParameters: ModelParameters = .default
        var isSpeaking: Bool = false
        var speakingMessageId: UUID?
        var isRecording: Bool = false
        var recordingDuration: TimeInterval = 0
        var isTranscribing: Bool = false
        var showTokenUsage: Bool = true
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
    let attachmentRepository: AttachmentRepositoryProtocol
    let streamMessageUseCase: StreamMessageUseCaseProtocol
    let agentStreamUseCase: AgentStreamUseCaseProtocol
    let webSearchUseCase: WebSearchUseCaseProtocol
    let saveConversationUseCase: SaveConversationUseCaseProtocol
    private let synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol
    let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    let exportConversationUseCase: ExportConversationUseCaseProtocol
    let branchConversationUseCase: BranchConversationUseCaseProtocol
    let getChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol
    private let saveSelectedModelUseCase: SaveSelectedModelUseCaseProtocol
    let setWebSearchEnabledUseCase: SetWebSearchEnabledUseCaseProtocol
    private let resolveAudioModelIdsUseCase: ResolveAudioModelIdsUseCaseProtocol
    let getUserProfileContextUseCase: GetUserProfileContextUseCaseProtocol
    let getMemoryContextUseCase: GetMemoryContextUseCaseProtocol
    private let getConversationStartersUseCase: GetConversationStartersUseCaseProtocol
    private let playAudioUseCase: any PlayAudioUseCaseProtocol
    let recordAudioUseCase: any RecordAudioUseCaseProtocol
    let triggerHapticFeedbackUseCase: TriggerHapticFeedbackUseCaseProtocol
    let streamingBackgroundUseCase: StreamingBackgroundUseCaseProtocol
    let notifyStreamingCompletedUseCase: NotifyStreamingCompletedUseCaseProtocol
    var streamTask: Task<Void, Never>?
    var errorDismissTask: Task<Void, Never>?
    var durationTrackingTask: Task<Void, Never>?
    private var pendingConversation: Conversation?

    // MARK: - Init

    init(
        conversation: Conversation? = nil,
        state: State = .loading,
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository(),
        streamMessageUseCase: StreamMessageUseCaseProtocol = StreamMessageUseCase(),
        agentStreamUseCase: AgentStreamUseCaseProtocol = AgentStreamUseCase(),
        webSearchUseCase: WebSearchUseCaseProtocol = WebSearchUseCase(),
        saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase(),
        synthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol = SynthesizeSpeechUseCase(),
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCase(),
        exportConversationUseCase: ExportConversationUseCaseProtocol = ExportConversationUseCase(),
        branchConversationUseCase: BranchConversationUseCaseProtocol = BranchConversationUseCase(),
        getChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol = GetChatPreferencesUseCase(),
        saveSelectedModelUseCase: SaveSelectedModelUseCaseProtocol = SaveSelectedModelUseCase(),
        setWebSearchEnabledUseCase: SetWebSearchEnabledUseCaseProtocol = SetWebSearchEnabledUseCase(),
        resolveAudioModelIdsUseCase: ResolveAudioModelIdsUseCaseProtocol = ResolveAudioModelIdsUseCase(),
        getUserProfileContextUseCase: GetUserProfileContextUseCaseProtocol = GetUserProfileContextUseCase(),
        getMemoryContextUseCase: GetMemoryContextUseCaseProtocol = GetMemoryContextUseCase(),
        getConversationStartersUseCase: GetConversationStartersUseCaseProtocol = GetConversationStartersUseCase(),
        playAudioUseCase: any PlayAudioUseCaseProtocol = PlayAudioUseCase(),
        recordAudioUseCase: any RecordAudioUseCaseProtocol = RecordAudioUseCase(),
        triggerHapticFeedbackUseCase: TriggerHapticFeedbackUseCaseProtocol = TriggerHapticFeedbackUseCase(),
        streamingBackgroundUseCase: StreamingBackgroundUseCaseProtocol = StreamingBackgroundUseCase(),
        notifyStreamingCompletedUseCase: NotifyStreamingCompletedUseCaseProtocol = NotifyStreamingCompletedUseCase()
    ) {
        self.state = state
        self.pendingConversation = conversation
        self.fetchModelsUseCase = fetchModelsUseCase
        self.attachmentRepository = attachmentRepository
        self.streamMessageUseCase = streamMessageUseCase
        self.agentStreamUseCase = agentStreamUseCase
        self.webSearchUseCase = webSearchUseCase
        self.saveConversationUseCase = saveConversationUseCase
        self.synthesizeSpeechUseCase = synthesizeSpeechUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.exportConversationUseCase = exportConversationUseCase
        self.branchConversationUseCase = branchConversationUseCase
        self.getChatPreferencesUseCase = getChatPreferencesUseCase
        self.saveSelectedModelUseCase = saveSelectedModelUseCase
        self.setWebSearchEnabledUseCase = setWebSearchEnabledUseCase
        self.resolveAudioModelIdsUseCase = resolveAudioModelIdsUseCase
        self.getUserProfileContextUseCase = getUserProfileContextUseCase
        self.getMemoryContextUseCase = getMemoryContextUseCase
        self.getConversationStartersUseCase = getConversationStartersUseCase
        self.playAudioUseCase = playAudioUseCase
        self.recordAudioUseCase = recordAudioUseCase
        self.triggerHapticFeedbackUseCase = triggerHapticFeedbackUseCase
        self.streamingBackgroundUseCase = streamingBackgroundUseCase
        self.notifyStreamingCompletedUseCase = notifyStreamingCompletedUseCase
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
             .editMessage, .forkFromMessage, .branchedConversationConsumed, .toggleFavourite:
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
        case .attachmentAdded(let data, let fileName, let type):
            addAttachment(data: data, fileName: fileName, type: type)
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
            let savedModelId = getChatPreferencesUseCase.getSelectedModelId()
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

            let audioModelIds = resolveAudioModelIdsUseCase.execute(from: models)
            let starters = getConversationStartersUseCase.execute(count: 4)
            state = .loaded(LoadedState(
                conversation: pending,
                messages: pending?.messages ?? [],
                selectedModel: selectedModel,
                availableModels: chatModels,
                conversationStarters: (pending?.messages ?? []).isEmpty ? starters : [],
                systemPrompt: pending?.systemPrompt ?? "",
                modelParameters: pending?.modelParameters ?? .default,
                showTokenUsage: getChatPreferencesUseCase.getShowTokenUsage(),
                ttsModelId: audioModelIds.ttsModelId,
                transcriptionModelId: audioModelIds.transcriptionModelId,
                isWebSearchEnabled: getChatPreferencesUseCase.getIsWebSearchEnabled()
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
                isWebSearchEnabled: getChatPreferencesUseCase.getIsWebSearchEnabled()
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
        LogManager.info("selectModel id=\(model.id)")
        loadedState.selectedModel = model
        state = .loaded(loadedState)
        saveSelectedModelUseCase.execute(modelId: model.id)
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

    func addAttachment(data: Data, fileName: String, type: ChatMessage.AttachmentType) {
        guard case .loaded(var loadedState) = state else { return }
        let mime = mimeType(for: type, fileName: fileName)
        let folderId = loadedState.conversation?.id ?? loadedState.pendingSessionId
        let attachmentId = UUID()
        let placeholder = ChatMessage.Attachment(
            id: attachmentId,
            type: type,
            fileName: fileName,
            mimeType: mime,
            fileRelativePath: ""
        )
        do {
            let relativePath = try attachmentRepository.save(data: data, for: placeholder, conversationId: folderId)
            let saved = ChatMessage.Attachment(
                id: attachmentId,
                type: type,
                fileName: fileName,
                mimeType: mime,
                fileRelativePath: relativePath
            )
            loadedState.pendingAttachments.append(saved)
            state = .loaded(loadedState)
        } catch {
            LogManager.error("addAttachment failed to save to disk: \(error)")
        }
    }

    func removeAttachment(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }
        if let attachment = loadedState.pendingAttachments.first(where: { $0.id == id }) {
            try? attachmentRepository.delete(attachment: attachment)
        }
        loadedState.pendingAttachments.removeAll { $0.id == id }
        state = .loaded(loadedState)
    }

    func mimeType(for type: ChatMessage.AttachmentType, fileName: String) -> String {
        switch type {
        case .pdf: return "application/pdf"
        case .image:
            let ext = (fileName as NSString).pathExtension.lowercased()
            switch ext {
            case "png": return "image/png"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            default: return "image/jpeg"
            }
        }
    }

    func stopStreaming() {
        LogManager.debug("stopStreaming requested")
        streamTask?.cancel()
        streamTask = nil
        streamingBackgroundUseCase.end()
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isStreaming = false
        state = .loaded(loadedState)
        persistConversation()
    }

    func handleSuggestionTapped(_ prompt: String) {
        updateInput(prompt)
        sendMessage()
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
                    voice: getChatPreferencesUseCase.getSelectedTTSVoice(forModelId: ttsModelId)
                )
                await playAudioUseCase.play(data: audioData, messageId: message.id)
                guard case .loaded(var currentState) = state else { return }
                currentState.isSpeaking = false
                currentState.speakingMessageId = nil
                state = .loaded(currentState)
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
        playAudioUseCase.stop()
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
