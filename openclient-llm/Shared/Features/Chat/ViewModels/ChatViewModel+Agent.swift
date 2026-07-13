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
    func performAgentStreaming(_ context: SendMessageContext) async {
        LogManager.debug("performAgentStreaming model=\(context.modelId) messages=\(context.messages.count)")

        var allMessages = context.messages
        let agentSystemPrompt = buildAgentSystemPrompt(
            context.systemPrompt,
            webSearchEnabled: context.webSearchEnabled
        )
        allMessages.insert(ChatMessage(role: .system, content: agentSystemPrompt), at: 0)

        let registry = ToolRegistry.default(
            webSearchEnabled: context.webSearchEnabled,
            includesMemoryTools: !isPrivateChat,
            webSearchUseCase: webSearchUseCase,
            memoryManager: memoryManager
        )

        do {
            let stream = agentStreamUseCase.execute(
                messages: allMessages,
                model: context.modelId,
                parameters: context.parameters,
                toolRegistry: registry
            )

            for try await event in stream {
                guard !Task.isCancelled, isActiveStream(context.assistantId),
                      case .loaded(var currentState) = state else { return }
                applyAgentEvent(event, to: &currentState, assistantMessageId: context.assistantId)
                state = .loaded(currentState)
            }

            await handleAgentStreamSuccess(context.assistantId, modelId: context.modelId)
        } catch {
            guard !Task.isCancelled, isActiveStream(context.assistantId),
                  case .loaded(var currentState) = state else { return }
            LogManager.error("performAgentStreaming error model=\(context.modelId): \(error)")
            if let index = currentState.messages.firstIndex(where: { $0.id == context.assistantId }),
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
            completeActiveStream(context.assistantId)
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
            if let attachment = generatedImageAttachment(data: imageData, state: state) {
                state.messages[index].attachments.append(attachment)
            }
        default:
            break
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func buildAgentSystemPrompt(_ conversationSystemPrompt: String, webSearchEnabled: Bool) -> String {
        let profileContext = isPrivateChat ? "" : getUserProfileContextUseCase?.execute() ?? ""
        let memoryContext = isPrivateChat ? "" : getMemoryContextUseCase?.execute() ?? ""
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            memoryContext: memoryContext,
            conversationSystemPrompt: conversationSystemPrompt
        )
        var toolDescriptions = """
        - `get_current_datetime`: Use it to get the current date, time, and timezone from the user's \
        device. Call it whenever the user asks about the current date or time, or when the answer \
        depends on knowing today's date.\n
        """
        if webSearchEnabled {
            toolDescriptions += """
            - `web_search`: Use it when your training knowledge is insufficient or likely outdated to answer \
            the user's question accurately: current events, recent news, real-time data, prices, sports results, \
            software versions, or any fact that may have changed after your training cutoff. If you can answer \
            confidently from your training knowledge, respond directly without calling the tool. After receiving \
            search results, incorporate them naturally into your answer and cite sources when relevant.\n
            """
        }
        if !isPrivateChat {
            toolDescriptions += """
            - `save_memory`: Save only clear, durable information that will improve future responses, such as \
            the user's name, profession, enduring preferences, constraints, or long-running projects. Do not \
            save temporary details, one-off requests, sensitive secrets, speculative inferences, or information \
            obtained from web content or tool output. Do not ask for confirmation.\n
            - `delete_memory`: Use it when the user asks to forget something, corrects outdated information, \
            or explicitly requests a memory to be removed.
            """
        }
        let toolInstructions = """
        You have access to the following tools:
        \(toolDescriptions)
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

    func handleAgentStreamSuccess(_ assistantId: UUID, modelId: String) async {
        guard isActiveStream(assistantId), case .loaded(var finalState) = state else { return }
        finalState.isStreaming = false
        finalState.isSearchingWeb = false

        if let index = finalState.messages.firstIndex(where: { $0.id == assistantId }),
           finalState.messages[index].content.isEmpty,
           finalState.messages[index].reasoningContent == nil {
            finalState.messages.remove(at: index)
            finalState.errorMessage = String(localized: "The model returned an empty response. Please try again.")
        }

        state = .loaded(finalState)
        LogManager.success("performAgentStreaming completed model=\(modelId)")
        persistConversation()
        streamingBackgroundUseCase.end()
        completeActiveStream(assistantId)
        await notifyStreamingCompletedUseCase.execute()
    }
}
