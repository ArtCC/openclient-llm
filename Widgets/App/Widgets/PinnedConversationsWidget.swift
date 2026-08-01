//
//  PinnedConversationsWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 01/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - PinnedConversationsWidget

/// Widget that shows pinned conversations and opens them directly in OpenClient.
struct PinnedConversationsWidget: Widget {
    // MARK: - Properties

    static let kind = AppGroupStore.pinnedConversationsWidgetKind

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PinnedConversationsProvider()) { entry in
            PinnedConversationsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Pinned Conversations"))
        .description(String(localized: "Keep your important conversations close at hand."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - PinnedConversationsEntry

struct PinnedConversationsEntry: TimelineEntry {
    let date: Date
    let conversations: [WidgetConversation]
}

// MARK: - PinnedConversationsProvider

struct PinnedConversationsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedConversationsEntry {
        PinnedConversationsEntry(date: Date(), conversations: pinnedPlaceholderConversations)
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedConversationsEntry) -> Void) {
        let conversations = AppGroupStore.loadPinnedConversations()
        completion(PinnedConversationsEntry(
            date: Date(),
            conversations: conversations.isEmpty ? pinnedPlaceholderConversations : conversations
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedConversationsEntry>) -> Void) {
        let entry = PinnedConversationsEntry(date: Date(), conversations: AppGroupStore.loadPinnedConversations())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - PinnedConversationsWidgetView

private struct PinnedConversationsWidgetView: View {
    // MARK: - Properties

    let entry: PinnedConversationsEntry

    @Environment(\.widgetFamily) private var family

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if entry.conversations.isEmpty {
                emptyState
            } else {
                conversationsList
            }
        }
    }
}

// MARK: - Private

private extension PinnedConversationsWidgetView {
    var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "pin.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(String(localized: "Pinned"))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(2.5)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "pin.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No pinned conversations"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var conversationsList: some View {
        let maxItems = family == .systemMedium ? 2 : 6
        return VStack(spacing: 0) {
            ForEach(Array(entry.conversations.prefix(maxItems).enumerated()), id: \.element.id) { index, conversation in
                if index > 0 {
                    Divider()
                        .padding(.leading, 12)
                }
                WidgetConversationRow(conversation: conversation)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Placeholder data

private let pinnedPlaceholderConversations: [WidgetConversation] = [
    WidgetConversation(
        id: UUID(),
        title: String(localized: "Important conversation"),
        modelId: "gpt-4o",
        lastMessagePreview: String(localized: "Your pinned conversation appears here."),
        updatedAt: Date(),
        isPinned: true
    )
]
