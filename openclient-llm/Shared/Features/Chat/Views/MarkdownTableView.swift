//
//  MarkdownTableView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MarkdownTableView: View {
    // MARK: - Properties

    let headers: [String]
    let rows: [[String]]

    // MARK: - View

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    dataRow(row, isAlternate: index % 2 != 0)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Private

private extension MarkdownTableView {
    var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                cellView(attributedContent(for: header), isBold: true)
                    .background(.ultraThinMaterial)
                if index < headers.count - 1 {
                    verticalDivider
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appAccent.opacity(0.3))
                .frame(height: 1)
        }
    }

    func dataRow(_ cells: [String], isAlternate: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                cellView(attributedContent(for: cell), isBold: false)
                    .background(isAlternate ? Color.primary.opacity(0.03) : Color.clear)
                if index < cells.count - 1 {
                    verticalDivider
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
    }

    func cellView(_ content: AttributedString, isBold: Bool) -> some View {
        Text(content)
            .font(isBold ? .subheadline.weight(.semibold) : .subheadline)
            .foregroundStyle(Color.primary)
            .textSelection(.enabled)
            .frame(minWidth: 60, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    var verticalDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
    }

    func attributedContent(for text: String) -> AttributedString {
        if let result = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return result
        }
        return AttributedString(text)
    }
}

#Preview {
    VStack(spacing: 16) {
        MarkdownTableView(
            headers: ["Name", "Type", "Description"],
            rows: [
                ["id", "Int", "Unique identifier"],
                ["name", "String", "User's **full name**"],
                ["email", "String", "Contact email with `code`"]
            ]
        )

        MarkdownTableView(
            headers: ["Feature", "Status"],
            rows: [
                ["Markdown", "Done"],
                ["Tables", "Done"],
                ["Syntax Highlighting", "Pending"]
            ]
        )
    }
    .padding()
}
