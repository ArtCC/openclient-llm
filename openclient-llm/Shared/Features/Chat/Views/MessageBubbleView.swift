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
    var isStreaming: Bool = false

    // MARK: - View

    var body: some View {
        switch message.role {
        case .user:
            userMessageLayout
        case .assistant, .system:
            assistantMessageLayout
        }
    }
}

// MARK: - Private

private extension MessageBubbleView {
    var userMessageLayout: some View {
        HStack {
            Spacer(minLength: 60)

            Text(message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundStyle(Color.primary)
                .glassEffect(
                    .regular.tint(.accent),
                    in: .rect(cornerRadius: 18)
                )
        }
    }

    var assistantMessageLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                markdownText
                    .textSelection(.enabled)
            }

            Spacer(minLength: 40)
        }
    }

    var markdownText: Text {
        let content = isStreaming
            ? message.content + " ▌"
            : message.content

        if let attributed = try? AttributedString(
            markdown: content,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributed)
        }

        return Text(content)
    }
}

#Preview("User message") {
    MessageBubbleView(
        message: ChatMessage(role: .user, content: "Hello, how are you?")
    )
    .padding()
}

#Preview("Assistant message") {
    MessageBubbleView(
        message: ChatMessage(
            role: .assistant,
            content: "I'm doing great! **How can I help you** today?"
        )
    )
    .padding()
}

#Preview("Streaming message") {
    MessageBubbleView(
        message: ChatMessage(
            role: .assistant,
            content: "Let me think about that..."
        ),
        isStreaming: true
    )
    .padding()
}
