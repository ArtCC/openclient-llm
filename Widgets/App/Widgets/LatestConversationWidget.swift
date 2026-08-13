//
//  LatestConversationWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 01/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - LatestConversationWidget

/// Widget that opens the most recently updated conversation in OpenClient.
struct LatestConversationWidget: Widget {
    // MARK: - Properties

    static let kind = AppGroupStore.latestConversationWidgetKind

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LatestConversationProvider()) { entry in
            LatestConversationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Continue Chat"))
        .description(String(localized: "Jump back into your latest conversation."))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - LatestConversationEntry

struct LatestConversationEntry: TimelineEntry {
    let date: Date
    let conversation: WidgetConversation?
}

// MARK: - LatestConversationProvider

struct LatestConversationProvider: TimelineProvider {
    func placeholder(in context: Context) -> LatestConversationEntry {
        LatestConversationEntry(date: Date(), conversation: latestPlaceholderConversation)
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestConversationEntry) -> Void) {
        let conversation = AppGroupStore.loadConversations().first
        completion(LatestConversationEntry(
            date: Date(),
            conversation: conversation ?? latestPlaceholderConversation
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestConversationEntry>) -> Void) {
        let entry = LatestConversationEntry(date: Date(), conversation: AppGroupStore.loadConversations().first)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - LatestConversationWidgetView

private struct LatestConversationWidgetView: View {
    // MARK: - Properties

    let entry: LatestConversationEntry

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.vertical, 5)
            if let conversation = entry.conversation {
                conversationCard(conversation)
            } else {
                emptyState
            }
        }
    }
}

// MARK: - Private

private extension LatestConversationWidgetView {
    var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.uturn.forward.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(String(localized: "Continue"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .frame(height: 30)
        .padding(.horizontal, 2.5)
    }

    @ViewBuilder
    func conversationCard(_ conversation: WidgetConversation) -> some View {
        if let url = URL(string: "openclient://conversation?id=\(conversation.id.uuidString)") {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(conversation.modelColor)
                            .frame(width: 8, height: 8)
                        Text(conversation.modelId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .privacySensitive()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
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
                            .lineLimit(2)
                            .privacySensitive()
                    }
                    Spacer(minLength: 0)
                    Text(conversation.updatedAt, style: .relative)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
                .padding(2.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No conversations yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder data

private let latestPlaceholderConversation = WidgetConversation(
    id: UUID(),
    title: String(localized: "Continue your latest chat"),
    modelId: "gpt-4o",
    lastMessagePreview: String(localized: "Tap to return to your conversation."),
    updatedAt: Date()
)
