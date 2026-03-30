//
//  MessageBubbleView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MessageBubbleView: View {
    // MARK: - Properties

    let message: ChatMessage

    // MARK: - View

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleContent

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Private

private extension MessageBubbleView {
    var bubbleBackground: Color {
        switch message.role {
        case .user:
            Color("UserBubble")
        case .assistant, .system:
            Color("AssistantBubble")
        }
    }

    @ViewBuilder
    var bubbleContent: some View {
        let baseText = Text(message.content)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(bubbleForeground)

        switch message.role {
        case .user:
            baseText
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        case .assistant, .system:
            baseText
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    var bubbleForeground: Color {
        switch message.role {
        case .user:
            Color("UserBubbleText")
        case .assistant, .system:
            Color("AssistantBubbleText")
        }
    }
}

#Preview("User message") {
    MessageBubbleView(message: ChatMessage(role: .user, content: "Hello, how are you?"))
        .padding()
}

#Preview("Assistant message") {
    MessageBubbleView(
        message: ChatMessage(
            role: .assistant,
            content: "I'm doing great! How can I help you today?"
        )
    )
    .padding()
}
