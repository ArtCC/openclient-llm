//
//  ChatView+Attachments.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Error Banner & Attachment Preview

extension ChatView {
    // MARK: - Error Banner

    @ViewBuilder
    func errorBanner(_ errorMessage: String?) -> some View {
        if let errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(errorMessage)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.85))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Attachment Preview

    @ViewBuilder
    func attachmentPreview(
        _ loadedState: ChatViewModel.LoadedState,
        send: @escaping (ChatViewModel.Event) -> Void
    ) -> some View {
        if !loadedState.pendingAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(loadedState.pendingAttachments) { attachment in
                        attachmentThumbnail(attachment, onRemove: { send(.attachmentRemoved(attachment.id)) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    func attachmentThumbnail(_ attachment: ChatMessage.Attachment, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.type == .image ? "photo" : "doc.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(attachment.fileName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}
