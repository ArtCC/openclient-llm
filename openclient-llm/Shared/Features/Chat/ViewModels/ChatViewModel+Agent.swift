//
//  ChatViewModel+Agent.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Agent streaming helpers

extension ChatViewModel {
    func performAgentStreaming(
        messages: [ChatMessage],
        model: String,
        assistantMessageId: UUID,
        systemPrompt: String,
        parameters: ModelParameters
    ) async {
        LogManager.debug("performAgentStreaming model=\(model) messages=\(messages.count)")

        var allMessages = messages
        let systemMessage = ChatMessage(role: .system, content: buildAgentSystemPrompt(systemPrompt))
        allMessages.insert(systemMessage, at: 0)

        let registry = ToolRegistry.default(webSearchUseCase: webSearchUseCase)

        do {
            let stream = agentStreamUseCase.execute(
                messages: allMessages,
                model: model,
                parameters: parameters,
                toolRegistry: registry
            )

            for try await event in stream {
                guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
                applyAgentEvent(event, to: &currentState, assistantMessageId: assistantMessageId)
                state = .loaded(currentState)
            }

            guard case .loaded(var finalState) = state else { return }
            finalState.isStreaming = false
            finalState.isSearchingWeb = false
            state = .loaded(finalState)
            LogManager.success("performAgentStreaming completed model=\(model)")
            persistConversation()
        } catch {
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            LogManager.error("performAgentStreaming error model=\(model): \(error)")
            if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }),
               currentState.messages[index].content.isEmpty {
                currentState.messages.remove(at: index)
            }
            currentState.isStreaming = false
            currentState.isSearchingWeb = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
            persistConversation()
        }
    }

    func applyAgentEvent(_ event: AgentEvent, to state: inout LoadedState, assistantMessageId: UUID) {
        // Handle events that update UI state (no message index needed)
        switch event {
        case .toolCallStarted:
            state.isSearchingWeb = true
            return
        case .toolCallCompleted(_, _, let searchResults):
            state.isSearchingWeb = false
            mergeSearchResults(searchResults, into: &state, assistantMessageId: assistantMessageId)
            return
        case .completed:
            return
        default:
            break
        }

        // All remaining events update the assistant message content
        guard let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) else { return }

        switch event {
        case .token(let text):
            state.messages[index].content += text
        case .reasoning(let text):
            state.messages[index].reasoningContent = (state.messages[index].reasoningContent ?? "") + text
        case .usage(let usage):
            state.messages[index].tokenUsage = usage
        case .image(let imageData):
            let attachment = ChatMessage.Attachment(
                type: .image,
                fileName: String(localized: "Generated Image"),
                data: imageData
            )
            state.messages[index].attachments.append(attachment)
        default:
            break
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func buildAgentSystemPrompt(_ conversationSystemPrompt: String) -> String {
        let profileContext = getUserProfileContextUseCase.execute()
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            conversationSystemPrompt: conversationSystemPrompt
        )
        let toolInstructions = """
        You have access to a `web_search` tool. Use it when the user asks about current events, \
        recent information, real-time data, or anything that may require up-to-date knowledge. \
        After receiving search results, incorporate them naturally into your answer and cite sources \
        when relevant. Respond using whatever format best serves the answer (Markdown, lists, \
        code blocks, tables, etc.).
        """
        return effectiveSystemPrompt.isEmpty
            ? toolInstructions
            : "\(effectiveSystemPrompt)\n\n\(toolInstructions)"
    }

    func mergeSearchResults(
        _ searchResults: [LiteLLMSearchResult]?,
        into state: inout LoadedState,
        assistantMessageId: UUID
    ) {
        guard let results = searchResults, !results.isEmpty,
              let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) else { return }
        var merged = state.messages[index].webSearchResults ?? []
        merged.append(contentsOf: results)
        state.messages[index].webSearchResults = merged
    }
}
