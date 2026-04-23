//
//  QuickActionsWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - QuickActionsWidget

/// Medium WidgetKit widget with two side-by-side action buttons:
/// "New Chat" and "Search". Each tap deep-links into the corresponding
/// section of OpenClient.
struct QuickActionsWidget: Widget {
    // MARK: - Properties

    static let kind: String = "com.artcc.openclient-llm.widget.quick-actions"

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickActionsEntryProvider()) { _ in
            QuickActionsWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Quick Actions"))
        .description(String(localized: "Start a new chat or search your conversations."))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - QuickActionsWidgetView

private struct QuickActionsWidgetView: View {
    var body: some View {
        VStack(spacing: 0) {
            if let newChatURL = URL(string: "openclient://new-chat"),
               let searchURL = URL(string: "openclient://search") {
                QuickActionRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: String(localized: "New Chat"),
                    subtitle: String(localized: "Start a conversation"),
                    url: newChatURL
                )
                Divider()
                    .padding(.leading, 68)
                QuickActionRow(
                    icon: "magnifyingglass",
                    label: String(localized: "Search"),
                    subtitle: String(localized: "Find past conversations"),
                    url: searchURL
                )
            }
        }
    }
}

// MARK: - QuickActionRow

private struct QuickActionRow: View {
    // MARK: - Properties

    let icon: String
    let label: String
    let subtitle: String
    let url: URL

    // MARK: - View

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - QuickActionsEntryProvider

private struct QuickActionsEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        completion(Timeline(entries: [QuickActionsEntry(date: Date())], policy: .never))
    }
}

// MARK: - QuickActionsEntry

private struct QuickActionsEntry: TimelineEntry {
    let date: Date
}
