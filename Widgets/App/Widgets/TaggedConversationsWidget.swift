//
//  TaggedConversationsWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 01/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - TaggedConversationsWidget

/// Widget that shows conversations assigned to a tag selected in the widget configuration.
struct TaggedConversationsWidget: Widget {
    // MARK: - Properties

    static let kind = AppGroupStore.taggedConversationsWidgetKind

    // MARK: - Body

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: TaggedConversationsWidgetIntent.self,
            provider: TaggedConversationsProvider()
        ) { entry in
            TaggedConversationsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Tagged Conversations"))
        .description(String(localized: "See conversations for a selected tag."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - TaggedConversationsEntry

struct TaggedConversationsEntry: TimelineEntry {
    let date: Date
    let tag: String
    let conversations: [WidgetConversation]
}

// MARK: - TaggedConversationsProvider

struct TaggedConversationsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaggedConversationsEntry {
        TaggedConversationsEntry(
            date: Date(),
            tag: String(localized: "Work"),
            conversations: taggedPlaceholderConversations
        )
    }

    func snapshot(
        for configuration: TaggedConversationsWidgetIntent,
        in context: Context
    ) async -> TaggedConversationsEntry {
        makeEntry(for: configuration)
    }

    func timeline(
        for configuration: TaggedConversationsWidgetIntent,
        in context: Context
    ) async -> Timeline<TaggedConversationsEntry> {
        let entry = makeEntry(for: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

// MARK: - TaggedConversationsWidgetView

private struct TaggedConversationsWidgetView: View {
    // MARK: - Properties

    let entry: TaggedConversationsEntry

    @Environment(\.widgetFamily) private var family

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.vertical, 5)
            if entry.conversations.isEmpty {
                emptyState
            } else {
                conversationsList
            }
        }
    }
}

// MARK: - Private

private extension TaggedConversationsProvider {
    func makeEntry(for configuration: TaggedConversationsWidgetIntent) -> TaggedConversationsEntry {
        let allTags = String(localized: "All Tags")
        let selectedTag = configuration.tag ?? allTags
        let conversations = AppGroupStore.loadConversations()
        let filtered = selectedTag == allTags
            ? conversations
            : conversations.filter { $0.tags.contains(selectedTag) }
        return TaggedConversationsEntry(date: Date(), tag: selectedTag, conversations: filtered)
    }
}

private extension TaggedConversationsWidgetView {
    var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(entry.tag)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 2.5)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No conversations for this tag"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var conversationsList: some View {
        let maxItems = family == .systemMedium ? 2 : 5
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

private let taggedPlaceholderConversations: [WidgetConversation] = [
    WidgetConversation(
        id: UUID(),
        title: String(localized: "Plan the next project"),
        modelId: "gpt-4o",
        lastMessagePreview: String(localized: "The project notes are ready to review."),
        updatedAt: Date(),
        tags: [String(localized: "Work")]
    ),
    WidgetConversation(
        id: UUID(),
        title: String(localized: "Prepare meeting notes"),
        modelId: "claude-3-5-sonnet",
        lastMessagePreview: String(localized: "Here is a concise summary of the meeting."),
        updatedAt: Date().addingTimeInterval(-3600),
        tags: [String(localized: "Work")]
    )
]
