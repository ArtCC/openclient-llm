//
//  ChatViewModel+Streaming.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Streaming helpers

extension ChatViewModel {
    func performStreaming(_ sendContext: SendMessageContext) async {
        let assistantMessageId = sendContext.assistantId
        LogManager.debug("performStreaming model=\(sendContext.modelId) messages=\(sendContext.messages.count)")
        do {
            let requestContext = try buildRequestContext(
                messages: sendContext.messages,
                systemPrompt: sendContext.systemPrompt,
                configuration: RequestContextConfiguration(
                    selectedModel: sendContext.selectedModel,
                    contextWindowTokens: sendContext.contextWindowTokens,
                    summary: sendContext.contextSummary,
                    summaryCursorMessageId: sendContext.contextSummaryCursorMessageId,
                    tools: []
                )
            )
            var allMessages = requestContext.messages
            if !requestContext.effectiveSystemPrompt.isEmpty {
                allMessages.insert(ChatMessage(role: .system, content: requestContext.effectiveSystemPrompt), at: 0)
            }
            let stream = streamMessageUseCase.execute(
                messages: allMessages,
                model: sendContext.modelId,
                parameters: parametersCappedToModelOutput(
                    sendContext.parameters,
                    model: sendContext.selectedModel
                )
            )
            for try await chunk in stream {
                guard !Task.isCancelled, isActiveStream(assistantMessageId),
                      case .loaded(var currentState) = state else { return }
                applyStreamChunk(chunk, to: &currentState, assistantMessageId: assistantMessageId)
                state = .loaded(currentState)
            }

            await finishStreaming(assistantMessageId, model: sendContext.modelId)
        } catch {
            guard !Task.isCancelled, isActiveStream(assistantMessageId),
                  case .loaded(var currentState) = state else { return }
            LogManager.error("performStreaming error model=\(sendContext.modelId): \(error)")
            if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }),
               currentState.messages[index].content.isEmpty {
                currentState.messages.remove(at: index)
            }
            currentState.isStreaming = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
            persistConversation()
            streamingBackgroundUseCase.end()
            completeActiveStream(assistantMessageId)
        }
    }

    func applyStreamChunk(_ chunk: StreamChunk, to state: inout LoadedState, assistantMessageId: UUID) {
        switch chunk {
        case .token(let token):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].content += token
            }
        case .reasoning(let text):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].reasoningContent = (state.messages[index].reasoningContent ?? "") + text
            }
        case .usage(let usage):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].tokenUsage = usage
            }
            refreshContextUsage(in: &state, calibratedPromptTokens: usage.promptTokens)
        case .image(let imageData):
            appendGeneratedImage(imageData, to: &state, assistantMessageId: assistantMessageId)
        }
    }

}

// MARK: - Private

private extension ChatViewModel {
    func finishStreaming(_ assistantMessageId: UUID, model: String) async {
        guard isActiveStream(assistantMessageId), case .loaded(var currentState) = state else { return }
        currentState.isStreaming = false
        removeEmptyAssistantMessage(assistantMessageId, from: &currentState)
        refreshContextUsage(in: &currentState)
        state = .loaded(currentState)
        LogManager.success("performStreaming completed model=\(model)")
        let didPersist = persistConversation()
        streamingBackgroundUseCase.end()
        completeActiveStream(assistantMessageId)
        if didPersist { scheduleCompactionIfNeeded() }
        await notifyStreamingCompletedUseCase.execute()
    }

    func removeEmptyAssistantMessage(_ assistantMessageId: UUID, from state: inout LoadedState) {
        guard let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }),
              state.messages[index].content.isEmpty,
              state.messages[index].reasoningContent == nil,
              state.messages[index].attachments.isEmpty else { return }
        state.messages.remove(at: index)
        state.errorMessage = String(localized: "The model returned an empty response. Please try again.")
    }

    func appendGeneratedImage(
        _ data: Data,
        to state: inout LoadedState,
        assistantMessageId: UUID
    ) {
        guard let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }),
              let attachment = generatedImageAttachment(data: data, state: state) else { return }
        state.messages[index].attachments.append(attachment)
    }

}
