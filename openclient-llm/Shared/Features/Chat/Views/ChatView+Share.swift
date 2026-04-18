//
//  ChatView+Share.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Share Extension

extension ChatView {
    func processShareItemIfNeeded(
        viewModel: ChatViewModel,
        shareItem: ShareExtensionItem?,
        onShareItemProcessed: (() -> Void)?
    ) async {
        guard let item = shareItem else { return }
        if let text = item.text {
            viewModel.send(.inputChanged(text))
        } else if let url = item.url {
            viewModel.send(.inputChanged(url))
        }
        for attachment in item.attachments {
            guard let data = ShareExtensionStore.loadAttachmentData(attachment) else { continue }
            let type: ChatMessage.AttachmentType = attachment.mimeType.hasPrefix("image/") ? .image : .pdf
            viewModel.send(.attachmentAdded(data: data, fileName: attachment.fileName, type: type))
        }
        ShareExtensionStore.clear()
        onShareItemProcessed?()
    }
}
