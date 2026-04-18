//
//  MessageBubbleView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageBubbleView: View {
    // MARK: - Properties

    let message: ChatMessage
    var isStreaming: Bool = false
    var isSpeaking: Bool = false
    var hasTTS: Bool = false
    var showTokenUsage: Bool = true
    var isLastMessage: Bool = false
    var onSpeakTapped: (() -> Void)?
    var onStopSpeakingTapped: (() -> Void)?
    var onEditTapped: (() -> Void)?
    var onRegenerateTapped: (() -> Void)?
    var onForkTapped: (() -> Void)?
    var onFavouriteTapped: (() -> Void)?
    @AppStorage("thinkingDisclosureExpanded") private var userThinkingPreference: Bool = true
    @State private var cursorVisible: Bool = false
    @State private var isThinkingExpanded: Bool = true
    @State private var programmaticExpansionChange: Bool = false
    @State private var parsedBlocks: [MessageBlock] = []

    // MARK: - View

    var body: some View {
        switch message.role {
        case .user:
            userMessageLayout
        case .assistant, .system:
            assistantMessageLayout
        case .tool:
            EmptyView()
        }
    }
}

// MARK: - Private

private extension MessageBubbleView {
    var userMessageLayout: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 4) {
                if !message.attachments.isEmpty {
                    attachmentsView
                }
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(
                        .regular.tint(Color.appAccent),
                        in: .rect(cornerRadius: 18)
                    )
            }
            .contentShape(Rectangle())
            .contextMenu {
                messageContextMenu(message.content)
            }
        }
    }

    var assistantMessageLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAccent)
                .frame(width: 28, height: 28)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 8) {
                if !message.attachments.isEmpty {
                    attachmentsView
                }

                if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                    thinkingDisclosureView(reasoning)
                }

                if message.content.isEmpty && isStreaming && (message.reasoningContent ?? "").isEmpty {
                    thinkingIndicator
                } else if !message.content.isEmpty {
                    blocksView
                }

                if let usage = message.tokenUsage, !isStreaming, showTokenUsage {
                    tokenUsageLabel(usage)
                }

                if let results = message.webSearchResults, !results.isEmpty, !isStreaming {
                    WebSearchSourcesView(results: results)
                }

                if !isStreaming && !message.content.isEmpty && message.role == .assistant && hasTTS {
                    speakButton
                }

                if !isStreaming, !message.content.isEmpty, isLastMessage, let onRegenerateTapped {
                    Button(action: onRegenerateTapped) {
                        Label(String(localized: "Regenerate Response"), systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .frame(minHeight: 28, alignment: .center)
            .contentShape(Rectangle())
            .contextMenu {
                if !message.content.isEmpty {
                    messageContextMenu(message.content)
                }
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            parsedBlocks = MarkdownParser.parse(message.content)
            programmaticExpansionChange = true
            isThinkingExpanded = userThinkingPreference
        }
        .onChange(of: message.content) {
            parsedBlocks = MarkdownParser.parse(message.content)
        }
        .onChange(of: isThinkingExpanded) { _, newValue in
            if programmaticExpansionChange {
                programmaticExpansionChange = false
            } else {
                userThinkingPreference = newValue
            }
        }
        .task(id: isStreaming) {
            guard isStreaming else {
                cursorVisible = false
                if message.reasoningContent != nil {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        programmaticExpansionChange = true
                        isThinkingExpanded = userThinkingPreference
                    }
                }
                return
            }
            programmaticExpansionChange = true
            isThinkingExpanded = true
            while !Task.isCancelled {
                cursorVisible.toggle()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    var attachmentsView: some View {
        HStack(spacing: 8) {
            ForEach(message.attachments) { attachment in
                switch attachment.type {
                case .image:
                    imageThumbnail(attachment)
                case .pdf:
                    documentCard(attachment)
                }
            }
        }
    }

    @ViewBuilder
    func imageThumbnail(_ attachment: ChatMessage.Attachment) -> some View {
        AttachmentImageView(attachment: attachment)
    }

    func documentCard(_ attachment: ChatMessage.Attachment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.type == .image ? "photo" : "doc.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(attachment.type == .image
                     ? String(localized: "Image")
                     : String(localized: "PDF Document"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    // MARK: - Context Menu

    @ViewBuilder
    func messageContextMenu(_ content: String) -> some View {
        Button {
            copyToClipboard(content)
        } label: {
            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
        }

        ShareLink(
            item: content,
            subject: Text(String(localized: "Chat Message")),
            message: Text(content)
        ) {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }

        if message.role == .user, let onEditTapped {
            Divider()
            Button {
                onEditTapped()
            } label: {
                Label(String(localized: "Edit & Resend"), systemImage: "pencil")
            }
        }

        if message.role == .assistant, isLastMessage, !isStreaming, let onRegenerateTapped {
            Divider()
            Button {
                onRegenerateTapped()
            } label: {
                Label(String(localized: "Regenerate Response"), systemImage: "arrow.clockwise")
            }
        }

        if let onForkTapped {
            Button {
                onForkTapped()
            } label: {
                Label(String(localized: "Fork from here"), systemImage: "arrow.branch")
            }
        }

        if let onFavouriteTapped {
            Divider()
            Button {
                onFavouriteTapped()
            } label: {
                Label(
                    message.isFavourite
                        ? String(localized: "Remove from Favourites")
                        : String(localized: "Add to Favourites"),
                    systemImage: message.isFavourite ? "star.slash" : "star"
                )
            }
        }
    }

    func copyToClipboard(_ text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }

    // MARK: - Blocks

    var blocksView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { index, block in
                let isLastBlock = index == parsedBlocks.count - 1

                switch block {
                case .text(let content):
                    textBlockView(content, isLast: isLastBlock)
                case .heading(let text, let level):
                    headingBlockView(text, level: level)
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
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
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

    func headingBlockView(_ text: String, level: Int) -> some View {
        let font: Font = {
            switch level {
            case 1: return .title
            case 2: return .title2
            case 3: return .title3
            default: return .headline
            }
        }()

        return Text(text)
            .font(font)
            .fontWeight(.semibold)
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

    func thinkingDisclosureView(_ reasoning: String) -> some View {
        DisclosureGroup(isExpanded: $isThinkingExpanded) {
            ScrollView {
                Text(reasoning)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
            }
            .frame(maxHeight: 200)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 11))
                Text(String(localized: "Thinking"))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isStreaming ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(.secondary))
            .opacity(isStreaming ? (cursorVisible ? 1.0 : 0.5) : 0.7)
        }
        .animation(.easeInOut(duration: 0.5), value: cursorVisible)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    func tokenUsageLabel(_ usage: TokenUsage) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: 9))
            Text(String(localized: "\(usage.totalTokens) tokens"))
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }

    var speakButton: some View {
        Button {
            if isSpeaking {
                onStopSpeakingTapped?()
            } else {
                onSpeakTapped?()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSpeaking ? "stop.circle.fill" : "speaker.wave.2")
                    .font(.system(size: 10))
                Text(isSpeaking
                     ? String(localized: "Stop")
                     : String(localized: "Listen"))
                    .font(.caption2)
            }
            .foregroundStyle(isSpeaking ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image Actions

    @ViewBuilder
    func imageSaveContextMenu(_ attachment: ChatMessage.Attachment) -> some View {
        EmptyView() // Context menu is handled inside AttachmentImageView
    }
}
