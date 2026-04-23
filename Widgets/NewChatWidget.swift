//
//  NewChatWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - NewChatWidget

/// Small WidgetKit widget that provides a one-tap shortcut to open OpenClient
/// in a new blank conversation from the home screen.
struct NewChatWidget: Widget {
    // MARK: - Properties

    static let kind: String = "com.artcc.openclient-llm.widget.new-chat"

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SingleEntryProvider()) { _ in
            NewChatWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "New Chat"))
        .description(String(localized: "Open a new conversation in OpenClient."))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - NewChatWidgetView

private struct NewChatWidgetView: View {
    var body: some View {
        if let url = URL(string: "openclient://new-chat") {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("OpenClient")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor)
                            .frame(width: 52, height: 52)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(String(localized: "New Chat"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - SingleEntryProvider

private struct SingleEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SingleEntry {
        SingleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SingleEntry) -> Void) {
        completion(SingleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SingleEntry>) -> Void) {
        completion(Timeline(entries: [SingleEntry(date: Date())], policy: .never))
    }
}

// MARK: - SingleEntry

private struct SingleEntry: TimelineEntry {
    let date: Date
}
