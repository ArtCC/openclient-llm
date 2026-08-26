//
//  ChatViewModel+Compaction.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Compaction

extension ChatViewModel {
    func prepareRequestContext(
        for sendContext: SendMessageContext,
        systemPrompt: String,
        tools: [ToolDefinition]
    ) async throws -> ContextWindowBuilder.Context {
        var summary = sendContext.contextSummary
        var cursorMessageId = sendContext.contextSummaryCursorMessageId
        var requestContext = try makeRequestContext(
            sendContext,
            systemPrompt: systemPrompt,
            tools: tools,
            summary: summary,
            cursorMessageId: cursorMessageId
        )
        guard !isPrivateChat,
              (sendContext.contextWindowTokens ?? sendContext.selectedModel.maxInputTokens ?? 0) > 0 else {
            return requestContext
        }

        while !requestContext.excludedMessages.isEmpty {
            let compacted = try await compactBeforeSending(
                sendContext,
                systemPrompt: systemPrompt,
                tools: tools,
                summary: summary,
                cursorMessageId: cursorMessageId
            )
            summary = compacted.summary
            cursorMessageId = compacted.cursorMessageId
            requestContext = try makeRequestContext(
                sendContext,
                systemPrompt: systemPrompt,
                tools: tools,
                summary: summary,
                cursorMessageId: cursorMessageId
            )
        }
        return requestContext
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
                let didPersist = await persistConversation()
                compactionTask = nil
                if didPersist { scheduleCompactionIfNeeded() }
            } catch is CancellationError {
                return
            } catch {
                LogManager.warning("compactConversation failed: \(error)")
            }
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func makeRequestContext(
        _ sendContext: SendMessageContext,
        systemPrompt: String,
        tools: [ToolDefinition],
        summary: String?,
        cursorMessageId: UUID?
    ) throws -> ContextWindowBuilder.Context {
        try buildRequestContext(
            messages: sendContext.messages,
            systemPrompt: systemPrompt,
            configuration: RequestContextConfiguration(
                selectedModel: sendContext.selectedModel,
                contextWindowTokens: sendContext.contextWindowTokens,
                summary: summary,
                summaryCursorMessageId: cursorMessageId,
                tools: tools
            )
        )
    }

    func compactBeforeSending(
        _ sendContext: SendMessageContext,
        systemPrompt: String,
        tools: [ToolDefinition],
        summary: String?,
        cursorMessageId: UUID?
    ) async throws -> CompactedConversation {
        try Task.checkCancellation()
        guard isActiveStream(sendContext.assistantId) else { throw CancellationError() }
        let configuration = makeCompactionConfiguration(
            summary: (summary, cursorMessageId),
            model: sendContext.selectedModel,
            contextWindowTokens: sendContext.contextWindowTokens,
            systemPrompt: systemPrompt,
            tools: tools
        )
        guard let compacted = try await compactConversationUseCase.execute(
            messages: sendContext.messages,
            configuration: configuration
        ), compactionCursorAdvanced(
            from: cursorMessageId,
            to: compacted.cursorMessageId,
            in: sendContext.messages
        ) else {
            throw ChatContextError.automaticCompactionFailed
        }
        try Task.checkCancellation()
        try await persistPreflightCompaction(
            compacted,
            expectedSummary: summary,
            expectedCursorMessageId: cursorMessageId,
            sendContext: sendContext
        )
        return compacted
    }

    func compactionConfiguration(
        for state: LoadedState,
        conversation: Conversation,
        model: LLMModel
    ) -> CompactionConfiguration {
        makeCompactionConfiguration(
            summary: (conversation.contextSummary, conversation.contextSummaryCursorMessageId),
            model: model,
            contextWindowTokens: state.contextWindowTokens,
            systemPrompt: state.systemPrompt,
            tools: contextTools(for: state)
        )
    }

    func makeCompactionConfiguration(
        summary: (text: String?, cursorMessageId: UUID?),
        model: LLMModel,
        contextWindowTokens: Int?,
        systemPrompt: String,
        tools: [ToolDefinition]
    ) -> CompactionConfiguration {
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: getUserProfileContextUseCase?.execute() ?? "",
            memoryContext: getMemoryContextUseCase?.execute() ?? "",
            conversationSystemPrompt: systemPrompt
        )
        return CompactionConfiguration(
            existingSummary: summary.text,
            summaryCursorMessageId: summary.cursorMessageId,
            model: model.id,
            contextWindowTokens: contextWindowTokens ?? model.maxInputTokens,
            maxOutputTokens: model.maxOutputTokens,
            systemPrompt: effectiveSystemPrompt,
            tools: tools
        )
    }

    func compactionCursorAdvanced(
        from currentCursorMessageId: UUID?,
        to newCursorMessageId: UUID,
        in messages: [ChatMessage]
    ) -> Bool {
        guard let newIndex = messages.firstIndex(where: { $0.id == newCursorMessageId }) else { return false }
        guard let currentCursorMessageId else { return true }
        guard let currentIndex = messages.firstIndex(where: { $0.id == currentCursorMessageId }) else { return false }
        return newIndex > currentIndex
    }

    func persistPreflightCompaction(
        _ compacted: CompactedConversation,
        expectedSummary: String?,
        expectedCursorMessageId: UUID?,
        sendContext: SendMessageContext
    ) async throws {
        guard case .loaded(var currentState) = state,
              isActiveStream(sendContext.assistantId),
              currentState.selectedModel?.id == sendContext.modelId,
              currentState.contextWindowTokens == sendContext.contextWindowTokens,
              currentState.conversation?.contextSummary == expectedSummary,
              currentState.conversation?.contextSummaryCursorMessageId == expectedCursorMessageId,
              hasSameRequestMessages(currentState.messages, as: sendContext) else {
            throw CancellationError()
        }
        currentState.conversation?.contextSummary = compacted.summary
        currentState.conversation?.contextSummaryCursorMessageId = compacted.cursorMessageId
        refreshContextUsage(in: &currentState)
        state = .loaded(currentState)
        let didPersist = await persistConversation()
        try Task.checkCancellation()
        guard didPersist, isActiveStream(sendContext.assistantId) else {
            throw ChatContextError.automaticCompactionFailed
        }
    }

    func hasSameRequestMessages(_ messages: [ChatMessage], as sendContext: SendMessageContext) -> Bool {
        messages.filter { $0.id != sendContext.assistantId }.elementsEqual(sendContext.messages) {
            $0.id == $1.id && $0.hasSameRequestContent(as: $1)
        }
    }
}
