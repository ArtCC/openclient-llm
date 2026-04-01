//
//  ChatViewModel+ImageGeneration.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Image Generation

extension ChatViewModel {
    func generateImage() {
        guard case .loaded(var loadedState) = state else { return }
        let prompt = loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !loadedState.isGeneratingImage else { return }

        guard let imageModel = loadedState.imageModel else {
            LogManager.warning("generateImage: no imageGeneration model available")
            let msg = String(
                localized: "No image generation model available. Add an image model to your LiteLLM server."
            )
            loadedState.errorMessage = msg
            state = .loaded(loadedState)
            scheduleErrorDismiss()
            return
        }
        LogManager.info("generateImage model=\(imageModel.id) prompt=\"\(String(prompt.prefix(80)))\"")

        if loadedState.conversation == nil {
            loadedState.conversation = Conversation(modelId: loadedState.selectedModel?.id ?? "", systemPrompt: "")
        }
        let userMessage = ChatMessage(role: .user, content: prompt)
        loadedState.messages.append(userMessage)
        loadedState.inputText = ""
        loadedState.isGeneratingImage = true
        loadedState.errorMessage = nil
        if loadedState.conversation?.title.isEmpty == true {
            loadedState.conversation?.title = String(prompt.prefix(50))
        }
        state = .loaded(loadedState)
        Task { await performImageGeneration(prompt: prompt, model: imageModel) }
    }

    func performImageGeneration(prompt: String, model: LLMModel) async {
        do {
            LogManager.debug("performImageGeneration model=\(model.id) mode=\(model.mode)")
            let generated = try await generateImageUseCase.execute(
                prompt: prompt,
                model: model.id,
                size: "1024x1024",
                mode: model.mode
            )
            let attachment = ChatMessage.Attachment(
                type: .image,
                fileName: generated.revisedPrompt ?? prompt,
                data: generated.imageData
            )
            let assistantMessage = ChatMessage(role: .assistant, content: "", attachments: [attachment])
            guard case .loaded(var currentState) = state else { return }
            currentState.messages.append(assistantMessage)
            currentState.isGeneratingImage = false
            state = .loaded(currentState)
            LogManager.success("performImageGeneration done imageData=\(generated.imageData.count) bytes")
            persistConversation()
        } catch {
            LogManager.error("performImageGeneration failed: \(error)")
            guard case .loaded(var currentState) = state else { return }
            currentState.isGeneratingImage = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
        }
    }
}
