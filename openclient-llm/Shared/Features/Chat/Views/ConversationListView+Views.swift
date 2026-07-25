//
//  ConversationListView+Views.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension ConversationListView {
    func modelBadge(_ modelId: String) -> some View {
        let name = modelId.split(separator: "/").last.map(String.init) ?? modelId
        return Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: .capsule)
    }

    func tagBadge(_ tag: ConversationTag) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .foregroundStyle(tag.color.displayColor)
            Text(tag.name)
                .foregroundStyle(.primary)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tag.color.displayColor.opacity(0.12), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(tag.name), \(tag.color.localizedName)"))
    }

    @ViewBuilder
    func branchBadge(for conversation: Conversation) -> some View {
        if conversation.parentConversationId != nil {
            Image(systemName: "arrow.branch")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
