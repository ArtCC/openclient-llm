//
//  WebSearchSourcesView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct WebSearchSourcesView: View {
    // MARK: - Properties

    let results: [LiteLLMSearchResult]

    // MARK: - View

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(results.prefix(5).enumerated()), id: \.offset) { index, result in
                    if let url = URL(string: result.url) {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 14, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.caption)
                                        .foregroundStyle(Color.appAccent)
                                        .lineLimit(2)
                                    Text(result.snippet)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                Text(results.count == 1
                     ? String(localized: "1 source")
                     : String(localized: "\(results.count) sources"))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
