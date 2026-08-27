//
//  ChatView+Scroll.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension ChatView {
    func messagesScrollView(_ messageListState: ChatMessageListState) -> some View {
        ScrollViewReader { proxy in
            scrollViewContent(messageListState)
                .onScrollPhaseChange { _, newPhase in
                    handleScrollPhaseChange(newPhase)
                }
                .modifier(ScrollTriggerModifier(
                    scrollToMessageId: $scrollToMessageId,
                    scrollState: $scrollState,
                    proxy: proxy,
                    snapshot: messageListState.scrollSnapshot,
                    renderedMessageRevision: renderedMessageRevision
                ))
                .modifier(ChatScrollDateModifier(
                    messages: messageListState.messages,
                    isUserScrolling: scrollState.isUserScrolling
                ))
                .overlay(alignment: .topTrailing) {
                    if !scrollState.isFollowingBottom,
                       !scrollState.isUserScrolling,
                       !messageListState.messages.isEmpty {
                        scrollAnchorButton(isTop: true) {
                            scrollState.detach()
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ChatScrollAnchor.top, anchor: .top)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !scrollState.isFollowingBottom,
                       !scrollState.isUserScrolling,
                       !messageListState.messages.isEmpty {
                        scrollAnchorButton(isTop: false) {
                            scrollState.followBottom()
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ChatScrollAnchor.bottom, anchor: .bottom)
                            }
                        }
                    }
                }
        }
    }
}

private extension ChatView {
    func handleScrollPhaseChange(_ phase: ScrollPhase) {
        if phase == .interacting {
            scrollState.userScrollBegan()
        } else if phase == .idle, scrollState.isUserScrolling {
            scrollState.userScrollEnded()
        }
    }

    func scrollViewContent(_ messageListState: ChatMessageListState) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 1)
                    .id(ChatScrollAnchor.top)
                if messageListState.messages.isEmpty {
                    ChatEmptyStateView(
                        selectedModel: messageListState.selectedModel,
                        conversationStarters: messageListState.conversationStarters,
                        isPrivateChat: isPrivateChat,
                        onSuggestionTapped: { viewModel.send(.suggestionTapped($0)) }
                    )
                } else {
                    messagesList(messageListState)
                }
                Color.clear
                    .frame(height: 1)
                    .id(ChatScrollAnchor.bottom)
            }
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#elseif os(macOS)
        .contentMargins(.top, 16, for: .scrollContent)
#endif
    }
}

private struct ChatScrollDateModifier: ViewModifier {
    let messages: [ChatMessage]
    let isUserScrolling: Bool

    @State private var visibleMessageIds: [UUID] = []

    func body(content: Content) -> some View {
        content
            .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.01) {
                visibleMessageIds = $0
            }
            .overlay(alignment: .top) {
                if isUserScrolling, let date = visibleMessageDate {
                    floatingDateLabel(date)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}

private extension ChatScrollDateModifier {
    var visibleMessageDate: Date? {
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
