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
    }

    func streamWithWebSearch(_ context: SendMessageContext) async {
        let useAgentMode = context.webSearchEnabled
            && context.modelCapabilities.contains(.functionCalling)
        if useAgentMode {
            await performAgentStreaming(
                messages: context.messages,
                model: context.modelId,
                assistantMessageId: context.assistantId,
                systemPrompt: context.systemPrompt,
                parameters: context.parameters
            )
        } else {
            await performStreaming(
                messages: context.messages,
                model: context.modelId,
                assistantMessageId: context.assistantId,
                systemPrompt: context.systemPrompt,
                parameters: context.parameters
            )
        }
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

        streamTask?.cancel()
        streamingBackgroundUseCase.begin { [weak self] in
            LogManager.warning("Background time expired — saving partial response")
            self?.streamTask?.cancel()
            self?.streamTask = nil
            guard let self, case .loaded(var currentState) = self.state else { return }
            currentState.isStreaming = false
            self.state = .loaded(currentState)
            self.persistConversation()
            Task { await self.notifyStreamingCompletedUseCase.executeExpired() }
        }
        streamTask = Task {
            await streamWithWebSearch(SendMessageContext(
                text: text,
                messages: currentMessages,
                modelId: model.id,
                assistantId: assistantId,
                systemPrompt: systemPrompt,
                parameters: parameters,
                webSearchEnabled: webSearchEnabled,
                modelCapabilities: modelCapabilities
            ))
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
}
