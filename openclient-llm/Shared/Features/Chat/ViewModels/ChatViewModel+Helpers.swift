//
//  ChatViewModel+Helpers.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum ChatContextError: LocalizedError {
    case latestTurnExceedsContextWindow

    var errorDescription: String? {
        String(localized: """
        The latest message and its attachments exceed this context window. \
        Increase the context window or shorten the message.
        """)
    }
}

struct RequestContextConfiguration {
    let selectedModel: LLMModel?
    let contextWindowTokens: Int?
    let summary: String?
    let summaryCursorMessageId: UUID?
    let tools: [ToolDefinition]
}

// MARK: - Internal helpers

extension ChatViewModel {
    func updateInput(_ text: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.inputText = text
        state = .loaded(loadedState)
    }

    func handleSuggestionTapped(_ prompt: String) {
        updateInput(prompt)
        sendMessage()
    }

    func updateContextWindow(_ tokens: Int?) {
        guard case .loaded(var loadedState) = state else { return }
        cancelCompaction()
        let normalizedTokens = tokens.flatMap { $0 > 0 ? $0 : nil }
        loadedState.contextWindowTokens = normalizedTokens
        loadedState.conversation?.contextWindowTokens = normalizedTokens
        refreshContextUsage(in: &loadedState)
        state = .loaded(loadedState)
        persistConversation()
    }

    func isActiveStream(_ assistantMessageId: UUID) -> Bool {
        activeAssistantMessageId == assistantMessageId
    }

    func completeActiveStream(_ assistantMessageId: UUID) {
        guard isActiveStream(assistantMessageId) else { return }
        activeAssistantMessageId = nil
        streamTask = nil
    }

    func cancelCompaction() {
        compactionTask?.cancel()
        compactionTask = nil
    }

    func cancelActiveStreaming() {
        streamTask?.cancel()
        streamTask = nil
        activeAssistantMessageId = nil
        streamingBackgroundUseCase.end()
        guard case .loaded(var loadedState) = state else { return }
        guard loadedState.isStreaming else { return }
        loadedState.isStreaming = false
        loadedState.isSearchingWeb = false
        loadedState.activeToolCallIds = []
        refreshContextUsage(in: &loadedState)
        state = .loaded(loadedState)
        persistConversation()
    }

    func stopStreaming() {
        LogManager.debug("stopStreaming requested")
        cancelActiveStreaming()
    }

    func beginStreamingBackground(for assistantMessageId: UUID) {
        streamingBackgroundUseCase.begin { [weak self] in
            LogManager.warning("Background time expired — saving partial response")
            guard let self, self.activeAssistantMessageId == assistantMessageId else { return }
            self.streamTask?.cancel()
            self.streamTask = nil
            self.activeAssistantMessageId = nil
            guard case .loaded(var currentState) = self.state else { return }
            currentState.isStreaming = false
            currentState.isSearchingWeb = false
            currentState.activeToolCallIds = []
            self.refreshContextUsage(in: &currentState)
            self.state = .loaded(currentState)
            self.persistConversation()
            Task { await self.notifyStreamingCompletedUseCase.executeExpired() }
        }
    }

    func buildEffectiveSystemPrompt(
        profileContext: String,
        memoryContext: String,
        conversationSystemPrompt: String
    ) -> String {
        let profile = profileContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = memoryContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversation = conversationSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []

        if !profile.isEmpty {
            parts.append("""
            The following is background information about the user. \
            Use it only to personalize your responses when relevant — \
            do not mention it proactively or make it the topic of conversation.
            \(profile)
            """)
        }

        if !memory.isEmpty {
            parts.append("""
            The following are facts you know about the user from previous conversations. \
            Use them only when directly relevant to what the user is asking — \
            never bring them up unprompted.
            \(memory)
            """)
        }

        if !conversation.isEmpty {
            parts.append(conversation)
        }

        return parts.joined(separator: "\n\n")
    }

    func refreshContextUsage(in loadedState: inout LoadedState, calibratedPromptTokens: Int? = nil) {
        let profileContext = isPrivateChat ? "" : getUserProfileContextUseCase?.execute() ?? ""
        let memoryContext = isPrivateChat ? "" : getMemoryContextUseCase?.execute() ?? ""
        let systemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            memoryContext: memoryContext,
            conversationSystemPrompt: loadedState.systemPrompt
        )
        let partition = contextPartition(
            messages: loadedState.messages,
            summary: loadedState.conversation?.contextSummary,
            cursorMessageId: loadedState.conversation?.contextSummaryCursorMessageId
        )
        let tools = contextTools(for: loadedState)
        loadedState.contextUsage = ContextWindowBuilder().usage(
            messages: partition.messages,
            systemPrompt: systemPrompt,
            summary: loadedState.conversation?.contextSummary,
            model: modelWithContextWindow(
                loadedState.selectedModel,
                override: loadedState.contextWindowTokens
            ),
            tools: tools,
            compactedMessageCount: partition.compactedCount,
            calibratedPromptTokens: calibratedPromptTokens
        )
    }

    func buildRequestContext(
        messages: [ChatMessage],
        systemPrompt: String,
        configuration: RequestContextConfiguration
    ) throws -> ContextWindowBuilder.Context {
        let profileContext = isPrivateChat ? "" : getUserProfileContextUseCase?.execute() ?? ""
        let memoryContext = isPrivateChat ? "" : getMemoryContextUseCase?.execute() ?? ""
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            memoryContext: memoryContext,
            conversationSystemPrompt: systemPrompt
        )
        let partition = contextPartition(
            messages: messages,
            summary: configuration.summary,
            cursorMessageId: configuration.summaryCursorMessageId
        )
        let context = ContextWindowBuilder().build(
            messages: partition.messages,
            systemPrompt: effectiveSystemPrompt,
            summary: configuration.summary,
            model: modelWithContextWindow(
                configuration.selectedModel,
                override: configuration.contextWindowTokens
            ),
            tools: configuration.tools,
            compactedMessageCount: partition.compactedCount
        )
        guard !context.isLatestTurnOverBudget else { throw ChatContextError.latestTurnExceedsContextWindow }
        return context
    }

    func parametersCappedToModelOutput(_ parameters: ModelParameters, model: LLMModel?) -> ModelParameters {
        guard let maxOutputTokens = model?.maxOutputTokens,
              let requestedMaxTokens = parameters.maxTokens else { return parameters }
        return ModelParameters(
            temperature: parameters.temperature,
            maxTokens: min(requestedMaxTokens, maxOutputTokens),
            topP: parameters.topP
        )
    }

    @discardableResult
    func persistConversation() -> Bool {
        guard !isPrivateChat else { return false }
        guard case .loaded(var loadedState) = state,
              var conversation = loadedState.conversation else { return false }

        conversation.messages = loadedState.messages
        conversation.systemPrompt = loadedState.systemPrompt
        conversation.modelParameters = loadedState.modelParameters
        conversation.contextWindowTokens = loadedState.contextWindowTokens
        conversation.updatedAt = Date()
        if let model = loadedState.selectedModel {
            conversation.modelId = model.id
        }
        loadedState.conversation = conversation
        state = .loaded(loadedState)

        do {
            try saveConversationUseCase.execute(conversation)
            NotificationCenter.default.post(name: .conversationDidUpdate, object: nil)
            onConversationUpdated?()
            return true
        } catch {
            LogManager.error("persistConversation failed: \(error)")
            return false
        }
    }

    func scheduleCompactionIfNeeded() {
        guard !isPrivateChat,
              case .loaded(let loadedState) = state,
              let conversation = loadedState.conversation,
              let model = loadedState.selectedModel else { return }
        let messageIds = loadedState.messages.map(\.id)
        let expectedSummary = conversation.contextSummary
        let expectedCursor = conversation.contextSummaryCursorMessageId
        let configuration = compactionConfiguration(for: loadedState, conversation: conversation, model: model)
        cancelCompaction()
        compactionTask = Task {
            do {
                let compacted = try await compactConversationUseCase.execute(
                    messages: loadedState.messages,
                    configuration: configuration
                )
                try Task.checkCancellation()
                guard let compacted,
                      case .loaded(var currentState) = state,
                      currentState.conversation?.id == conversation.id,
                      currentState.selectedModel?.id == model.id,
                      currentState.contextWindowTokens == loadedState.contextWindowTokens,
                      currentState.messages.map(\.id) == messageIds,
                      currentState.conversation?.contextSummary == expectedSummary,
                      currentState.conversation?.contextSummaryCursorMessageId == expectedCursor else { return }
                currentState.conversation?.contextSummary = compacted.summary
                currentState.conversation?.contextSummaryCursorMessageId = compacted.cursorMessageId
                refreshContextUsage(in: &currentState)
                state = .loaded(currentState)
                let didPersist = persistConversation()
                compactionTask = nil
                if didPersist { scheduleCompactionIfNeeded() }
            } catch is CancellationError {
                return
            } catch {
                LogManager.warning("compactConversation failed: \(error)")
            }
        }
    }

    func compactionConfiguration(
        for state: LoadedState,
        conversation: Conversation,
        model: LLMModel
    ) -> CompactionConfiguration {
        let systemPrompt = buildEffectiveSystemPrompt(
            profileContext: getUserProfileContextUseCase?.execute() ?? "",
            memoryContext: getMemoryContextUseCase?.execute() ?? "",
            conversationSystemPrompt: state.systemPrompt
        )
        return CompactionConfiguration(
            existingSummary: conversation.contextSummary,
            summaryCursorMessageId: conversation.contextSummaryCursorMessageId,
            model: model.id,
            contextWindowTokens: state.contextWindowTokens ?? model.maxInputTokens,
            maxOutputTokens: model.maxOutputTokens,
            systemPrompt: systemPrompt,
            tools: contextTools(for: state)
        )
    }

    func modelWithContextWindow(_ model: LLMModel?, override contextWindowTokens: Int?) -> LLMModel? {
        guard var model else { return nil }
        if let contextWindowTokens, contextWindowTokens > 0 {
            model.maxInputTokens = contextWindowTokens
        }
        return model
    }

    func contextPartition(
        messages: [ChatMessage],
        summary: String?,
        cursorMessageId: UUID?
    ) -> (messages: [ChatMessage], compactedCount: Int) {
        guard summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let cursorMessageId,
              let cursorIndex = messages.firstIndex(where: { $0.id == cursorMessageId }) else {
            return (messages, 0)
        }
        return (Array(messages.dropFirst(cursorIndex + 1)), cursorIndex + 1)
    }

    func contextTools(for loadedState: LoadedState) -> [ToolDefinition] {
        guard loadedState.selectedModel?.capabilities.contains(.functionCalling) == true else { return [] }
        return ToolRegistry.default(
            webSearchEnabled: loadedState.isWebSearchEnabled,
            includesMemoryTools: !isPrivateChat,
            webSearchUseCase: webSearchUseCase,
            memoryManager: memoryManager
        ).definitions
    }

    func generatedImageAttachment(
        data: Data,
        mimeType: String = "image/png",
        state: LoadedState
    ) -> ChatMessage.Attachment? {
        if isPrivateChat {
            return ChatMessage.Attachment(
                type: .image,
                fileName: String(localized: "Generated Image"),
                mimeType: mimeType,
                fileRelativePath: "",
                transientData: data
            )
        }
        let attachmentID = UUID()
        let placeholder = ChatMessage.Attachment(
            id: attachmentID,
            type: .image,
            fileName: String(localized: "Generated Image"),
            mimeType: mimeType,
            fileRelativePath: ""
        )
        guard let relativePath = try? attachmentRepository.save(
            data: data,
            for: placeholder,
            conversationId: state.conversation?.id ?? state.pendingSessionId
        ) else {
            LogManager.error("generatedImageAttachment: failed to save image")
            return nil
        }
        return ChatMessage.Attachment(
            id: attachmentID,
            type: .image,
            fileName: String(localized: "Generated Image"),
            mimeType: mimeType,
            fileRelativePath: relativePath
        )
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
