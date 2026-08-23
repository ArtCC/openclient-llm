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
                .overlay(alignment: .top) {
                    if scrollState.isUserScrolling,
                       let date = visibleMessageDate(
                           in: messageListState.messages,
                           visibleMessageIds: visibleMessageIds
                       ) {
                        floatingDateLabel(date)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
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
        .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.01) {
            visibleMessageIds = $0
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#elseif os(macOS)
        .contentMargins(.top, 16, for: .scrollContent)
#endif
    }
}
