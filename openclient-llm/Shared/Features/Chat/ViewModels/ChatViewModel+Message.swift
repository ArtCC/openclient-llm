//
//  ChatViewModel+Message.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Message

extension ChatViewModel {
    struct SendMessageContext {
        let text: String
        let messages: [ChatMessage]
        let modelId: String
        let assistantId: UUID
        let systemPrompt: String
        let parameters: ModelParameters
        let webSearchEnabled: Bool
        let modelCapabilities: [LLMModel.Capability]
        let selectedModel: LLMModel
        let contextWindowTokens: Int?
        let contextSummary: String?
        let contextSummaryCursorMessageId: UUID?
    }

    func streamWithWebSearch(_ context: SendMessageContext) async {
        let useAgentMode = context.modelCapabilities.contains(.functionCalling)
        if useAgentMode {
            await performAgentStreaming(context)
        } else {
            await performStreaming(context)
        }
    }

    func sendMessage() {
        guard case .loaded(var loadedState) = state else { return }
        let text = loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !loadedState.pendingAttachments.isEmpty,
              let model = loadedState.selectedModel, !loadedState.isStreaming else { return }
        LogManager.info("sendMessage model=\(model.id) attachments=\(loadedState.pendingAttachments.count)")

        let assistantId = prepareMessageState(text: text, model: model, loadedState: &loadedState)
        let currentMessages = loadedState.messages.filter { $0.id != assistantId }
        let systemPrompt = loadedState.systemPrompt
        let parameters = loadedState.modelParameters
        let webSearchEnabled = loadedState.isWebSearchEnabled
        let modelCapabilities = model.capabilities

        cancelCompaction()
        streamTask?.cancel()
        activeAssistantMessageId = assistantId
        beginStreamingBackground(for: assistantId)
        streamTask = Task {
            await streamWithWebSearch(SendMessageContext(
                text: text,
                messages: currentMessages,
                modelId: model.id,
                assistantId: assistantId,
                systemPrompt: systemPrompt,
                parameters: parameters,
                webSearchEnabled: webSearchEnabled,
                modelCapabilities: modelCapabilities,
                selectedModel: model,
                contextWindowTokens: loadedState.contextWindowTokens,
                contextSummary: loadedState.conversation?.contextSummary,
                contextSummaryCursorMessageId: loadedState.conversation?.contextSummaryCursorMessageId
            ))
        }
    }

    func prepareMessageState(text: String, model: LLMModel, loadedState: inout LoadedState) -> UUID {
        if loadedState.conversation == nil, !isPrivateChat {
            loadedState.conversation = Conversation(
                modelId: model.id,
                systemPrompt: loadedState.systemPrompt,
                contextWindowTokens: loadedState.contextWindowTokens
            )
        }
        let userMessage = ChatMessage(role: .user, content: text, attachments: loadedState.pendingAttachments)
        loadedState.messages.append(userMessage)
        loadedState.inputText = ""
        loadedState.pendingAttachments = []
        loadedState.isStreaming = true
        loadedState.errorMessage = nil
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        loadedState.messages.append(assistantMessage)
        refreshContextUsage(in: &loadedState)
        if loadedState.conversation?.title.isEmpty == true {
            loadedState.conversation?.title = text.isEmpty
                ? String(localized: "New Conversation")
                : String(text.prefix(50))
        }
        state = .loaded(loadedState)
        return assistantMessage.id
    }
}
