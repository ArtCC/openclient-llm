//
//  ChatView+Messages.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension ChatView {
    // MARK: - Messages List

    func messagesList(_ loadedState: ChatViewModel.LoadedState) -> some View {
        let tipMessageId = loadedState.messages.last {
            $0.role == .assistant && !$0.content.isEmpty
        }?.id

        return LazyVStack(spacing: 16) {
            ForEach(loadedState.messages) { message in
                let isLast = message.id == loadedState.messages.last?.id
                MessageBubbleView(
                    message: message,
                    isStreaming: loadedState.isStreaming && isLast,
                    isSpeaking: loadedState.speakingMessageId == message.id,
                    hasTTS: loadedState.ttsModelId != nil,
                    showTokenUsage: loadedState.showTokenUsage,
                    isLastMessage: isLast,
                    isRunningTool: isLast && !loadedState.activeToolCallIds.isEmpty,
                    showsMessageActionsTip: message.id == tipMessageId && !loadedState.isStreaming,
                    onSpeakTapped: { viewModel.send(.speakMessageTapped(message)) },
                    onStopSpeakingTapped: { viewModel.send(.stopSpeakingTapped) },
                    onEditTapped: message.role == .user ? {
                        editingMessage = message
                        editingMessageText = message.content
                    } : nil,
                    onRegenerateTapped: (message.role == .assistant && isLast) ? {
                        viewModel.send(.regenerateLastResponse)
                    } : nil,
                    onForkTapped: loadedState.conversation != nil ? {
                        viewModel.send(.forkFromMessage(message.id))
                    } : nil,
                    onFavouriteTapped: { viewModel.send(.toggleFavourite(message.id)) }
                )
                .id(message.id)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity)
    }
}
