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
    var onSpeakTapped: (() -> Void)?
    var onStopSpeakingTapped: (() -> Void)?
    @State private var cursorVisible: Bool = false
    @State private var expandedImageData: Data?

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
                        .regular.tint(Color.accentColor),
                        in: .rect(cornerRadius: 18)
                    )
            }
            .contextMenu {
                messageContextMenu(message.content)
            }
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
                if !message.attachments.isEmpty {
                    attachmentsView
                }

                if message.content.isEmpty && isStreaming {
                    thinkingIndicator
                } else if !message.content.isEmpty {
                    blocksView
                }

                if let usage = message.tokenUsage, !isStreaming, showTokenUsage {
                    tokenUsageLabel(usage)
                }

                if !isStreaming && !message.content.isEmpty && message.role == .assistant && hasTTS {
                    speakButton
                }
            }
            .frame(minHeight: 28, alignment: .center)
            .contextMenu {
                if !message.content.isEmpty {
                    messageContextMenu(message.content)
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
        if let image = platformImage(from: attachment.data) {
            #if os(iOS)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 175, height: 175)
                .clipShape(.rect(cornerRadius: 12))
                .contentShape(.rect(cornerRadius: 12))
                .onTapGesture { expandedImageData = attachment.data }
                .contextMenu { imageSaveContextMenu(attachment.data) }
                .sheet(item: Binding(
                    get: { expandedImageData.map { ExpandedImage(data: $0) } },
                    set: { if $0 == nil { expandedImageData = nil } }
                )) { expanded in
                    ImagePreviewView(data: expanded.data)
                }
            #elseif os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 175, height: 175)
                .clipShape(.rect(cornerRadius: 12))
                .contentShape(.rect(cornerRadius: 12))
                .onTapGesture { expandedImageData = attachment.data }
                .contextMenu { imageSaveContextMenu(attachment.data) }
                .sheet(item: Binding(
                    get: { expandedImageData.map { ExpandedImage(data: $0) } },
                    set: { if $0 == nil { expandedImageData = nil } }
                )) { expanded in
                    ImagePreviewView(data: expanded.data)
                }
            #endif
        } else {
            documentCard(attachment)
        }
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

    #if os(iOS)
    func platformImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
    #elseif os(macOS)
    func platformImage(from data: Data) -> NSImage? {
        NSImage(data: data)
    }
    #endif

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
    func imageSaveContextMenu(_ data: Data) -> some View {
#if os(iOS)
        Button {
            saveImageToPhotos(data)
        } label: {
            Label(String(localized: "Save to Photos"), systemImage: "photo.badge.plus")
        }
#elseif os(macOS)
        Button {
            saveImageToDownloads(data)
        } label: {
            Label(String(localized: "Save to Downloads"), systemImage: "arrow.down.circle")
        }
#endif
        Button {
            copyImageToClipboard(data)
        } label: {
            Label(String(localized: "Copy Image"), systemImage: "doc.on.doc")
        }
    }

#if os(iOS)
    func saveImageToPhotos(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
#elseif os(macOS)
    func saveImageToDownloads(_ data: Data) {
        let timestamp = Int(Date().timeIntervalSince1970)
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("generated-image-\(timestamp).png") else { return }
        try? data.write(to: url)
    }
#endif

    func copyImageToClipboard(_ data: Data) {
#if os(iOS)
        guard let image = UIImage(data: data) else { return }
        UIPasteboard.general.image = image
#elseif os(macOS)
        guard let image = NSImage(data: data) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
#endif
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
