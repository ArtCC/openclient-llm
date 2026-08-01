//
//  WidgetConversationRow.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 01/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - WidgetConversationRow

struct WidgetConversationRow: View {
    // MARK: - Properties

    let conversation: WidgetConversation

    // MARK: - View

    var body: some View {
        if let url = URL(string: "openclient://conversation?id=\(conversation.id.uuidString)") {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(conversation.modelColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title.isEmpty ? String(localized: "New Chat") : conversation.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .privacySensitive()
                        if !conversation.lastMessagePreview.isEmpty {
                            Text(conversation.lastMessagePreview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .privacySensitive()
                        }
                        Text(conversation.updatedAt, style: .relative)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .privacySensitive()
                    }
                }
                .padding(.horizontal, 2.5)
                .padding(.vertical, 7)
            }
        }
    }
}

// MARK: - WidgetConversation + modelColor

extension WidgetConversation {
    var modelColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .teal, .pink, .indigo]
        let hash = modelId.utf8.reduce(UInt64(5_381)) { partialResult, byte in
            (partialResult &* 33) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(colors.count))

        return colors[index]
    }
}
