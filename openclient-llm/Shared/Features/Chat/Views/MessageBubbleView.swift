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
    @State private var cursorVisible: Bool = false

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
                    .regular.tint(Color.accentColor),
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

            VStack(alignment: .leading, spacing: 8) {
                if message.content.isEmpty && isStreaming {
                    thinkingIndicator
                } else {
                    blocksView
                }
            }

            Spacer(minLength: 40)
        }
        .task(id: isStreaming) {
            guard isStreaming else {
                cursorVisible = false
                return
            }
            while !Task.isCancelled {
                cursorVisible.toggle()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    var blocksView: some View {
        let blocks = MarkdownParser.parse(message.content)

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                let isLastBlock = index == blocks.count - 1

                switch block {
                case .text(let content):
                    textBlockView(content, isLast: isLastBlock)

                case .codeBlock(let code, let language):
                    CodeBlockView(
                        code: isStreaming && isLastBlock
                            ? code
                            : code,
                        language: language
                    )
                }
            }
        }
    }

    func textBlockView(_ content: String, isLast: Bool) -> some View {
        let displayContent = isLast && isStreaming && cursorVisible
            ? content + "█"
            : content

        let attributed: AttributedString = {
            if let result = try? AttributedString(
                markdown: displayContent,
                options: .init(interpretedSyntax: .full)
            ) {
                return result
            }
            return AttributedString(displayContent)
        }()

        return Text(attributed)
            .foregroundStyle(Color.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var thinkingIndicator: some View {
        Text(String(localized: "Thinking..."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .phaseAnimator([0.4, 1.0]) { content, phase in
                content.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
    }
}

#Preview("User message") {
    MessageBubbleView(
        message: ChatMessage(role: .user, content: "Hello, how are you?")
    )
    .padding()
}

// swiftlint:disable line_length
#Preview("Assistant message") {
    MessageBubbleView(
        message: ChatMessage(
            role: .assistant,
            content: "I'm doing great! **How can I help you** today?\n\nHere's a list:\n- Item one\n- Item two\n- Item three"
        )
    )
    .padding()
}

#Preview("Code block") {
    MessageBubbleView(
        message: ChatMessage(
            role: .assistant,
            content: "Sure! Here's how to do it in Swift:\n\n```swift\nfunc greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\n```\n\nJust call `greet(name: \"World\")` and you're done."
        )
    )
    .padding()
}
// swiftlint:enable line_length

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
