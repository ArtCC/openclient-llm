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

        let registry = ToolRegistry.default(webSearchUseCase: webSearchUseCase, memoryManager: MemoryManager())

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
            streamingBackgroundUseCase.end()
            await notifyStreamingCompletedUseCase.execute()
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
            streamingBackgroundUseCase.end()
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
        applyAgentContentEvent(event, at: index, in: &state)
    }

    func applyAgentContentEvent(_ event: AgentEvent, at index: Int, in state: inout LoadedState) {
        switch event {
        case .token(let text):
            state.messages[index].content += text
        case .reasoning(let text):
            state.messages[index].reasoningContent = (state.messages[index].reasoningContent ?? "") + text
        case .usage(let usage):
            state.messages[index].tokenUsage = usage
        case .image(let imageData):
            let folderId = state.conversation?.id ?? state.pendingSessionId
            let attachmentId = UUID()
            let placeholder = ChatMessage.Attachment(
                id: attachmentId,
                type: .image,
                fileName: String(localized: "Generated Image"),
                mimeType: "image/png",
                fileRelativePath: ""
            )
            if let relativePath = try? attachmentRepository.save(
                data: imageData,
                for: placeholder,
                conversationId: folderId
            ) {
                let attachment = ChatMessage.Attachment(
                    id: attachmentId,
                    type: .image,
                    fileName: String(localized: "Generated Image"),
                    mimeType: "image/png",
                    fileRelativePath: relativePath
                )
                state.messages[index].attachments.append(attachment)
            } else {
                LogManager.error("applyAgentEvent: failed to save generated image")
            }
        default:
            break
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func buildAgentSystemPrompt(_ conversationSystemPrompt: String) -> String {
        let profileContext = getUserProfileContextUseCase.execute()
        let memoryContext = getMemoryContextUseCase.execute()
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            memoryContext: memoryContext,
            conversationSystemPrompt: conversationSystemPrompt
        )
        let toolInstructions = """
        You have access to the following tools:
        - `web_search`: Use it when your training knowledge is insufficient or likely outdated to answer \
        the user's question accurately: current events, recent news, real-time data, prices, sports results, \
        software versions, or any fact that may have changed after your training cutoff. If you can answer \
        confidently from your training knowledge, respond directly without calling the tool. After receiving \
        search results, incorporate them naturally into your answer and cite sources when relevant.
        - `save_memory`: Use it when the user shares important personal details, preferences, or context \
        that should be remembered in future conversations. Call it proactively when you identify information \
        worth remembering long-term.
        Respond using whatever format best serves the answer (Markdown, lists, code blocks, tables, etc.).
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
