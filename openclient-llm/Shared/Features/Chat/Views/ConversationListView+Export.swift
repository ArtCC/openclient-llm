//
//  ConversationListView+Export.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationListView {
    // MARK: - Export

    func conversationTitle(_ conversation: Conversation) -> String {
        if !conversation.title.isEmpty {
            return conversation.title
        }
        if let firstUserMessage = conversation.messages.first(where: { $0.role == .user }) {
            let preview = firstUserMessage.content.prefix(50)
            return preview.count < firstUserMessage.content.count
            ? "\(preview)..."
            : String(preview)
        }
        return String(localized: "New Chat")
    }

    func exportURL(for conversation: Conversation) -> URL? {
        guard let data = try? ExportConversationUseCase().execute(conversation) else { return nil }
        let raw = conversationTitle(conversation)
        let sanitized = raw
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "_", options: .regularExpression)
            .prefix(50)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(String(sanitized))
            .appendingPathExtension("json")
        try? data.write(to: url)
        return url
    }
}
