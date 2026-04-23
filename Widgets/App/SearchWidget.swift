//
//  SearchWidget.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - SearchWidget

/// Small WidgetKit widget that opens OpenClient directly in the Search tab.
struct SearchWidget: Widget {
    // MARK: - Properties

    static let kind: String = "com.artcc.openclient-llm.widget.search"

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SearchEntryProvider()) { _ in
            SearchWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Search"))
        .description(String(localized: "Open the search screen in OpenClient."))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - SearchWidgetView

private struct SearchWidgetView: View {
    var body: some View {
        if let url = URL(string: "openclient://search") {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor)
                            .frame(width: 52, height: 52)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Search"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Find past conversations")
                                .multilineTextAlignment(.leading)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(2.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - SearchEntryProvider

private struct SearchEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SearchEntry {
        SearchEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SearchEntry) -> Void) {
        completion(SearchEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SearchEntry>) -> Void) {
        completion(Timeline(entries: [SearchEntry(date: Date())], policy: .never))
    }
}

// MARK: - SearchEntry

private struct SearchEntry: TimelineEntry {
    let date: Date
}
