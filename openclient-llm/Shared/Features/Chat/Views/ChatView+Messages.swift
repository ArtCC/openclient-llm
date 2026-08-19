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
                let isStreamingMsg = loadedState.isStreaming && isLast
                let isEmptyAssistant = message.role == .assistant
                    && message.content.isEmpty
                    && message.reasoningContent == nil
                    && message.attachments.isEmpty

                if !isEmptyAssistant || isStreamingMsg {
                    MessageBubbleView(
                        message: message,
                        isStreaming: isStreamingMsg,
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
        }
        .scrollTargetLayout()
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scroll Navigation

    func scrollAnchorButton(isTop: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isTop ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(isTop ? .top : .bottom, 16)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    func visibleMessageDate(
        in messages: [ChatMessage],
        visibleMessageIds: [UUID]
    ) -> Date? {
        let visibleIds = Set(visibleMessageIds)
        return messages.first { visibleIds.contains($0.id) }?.timestamp
    }

    func floatingDateLabel(_ date: Date) -> some View {
        Text(floatingDateText(date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }

    func floatingDateText(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}
