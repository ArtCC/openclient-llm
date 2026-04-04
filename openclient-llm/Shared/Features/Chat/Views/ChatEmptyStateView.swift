//
//  ChatEmptyStateView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatEmptyStateView: View {
    // MARK: - Properties

    let selectedModel: LLMModel?
    let conversationStarters: [ConversationStarter]
    var onSuggestionTapped: (String) -> Void

    // MARK: - View

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)
                .frame(width: 80, height: 80)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(
                    String(localized: "How can I help you?")
                )
                .font(.poppins(.semiBold, size: 22, relativeTo: .title2))

                if selectedModel == nil {
                    Text(
                        String(
                            localized:
                                "Select a model to start chatting"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if selectedModel != nil {
                suggestionChipsGrid
            }

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Private

private extension ChatEmptyStateView {
    var suggestionChipsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 12
        ) {
            ForEach(conversationStarters) { starter in
                Button {
                    onSuggestionTapped(starter.text)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: starter.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(starter.text)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 14)
                )
            }
        }
    }
}

#Preview {
    ChatEmptyStateView(
        selectedModel: nil,
        conversationStarters: [],
        onSuggestionTapped: { _ in }
    )
}
