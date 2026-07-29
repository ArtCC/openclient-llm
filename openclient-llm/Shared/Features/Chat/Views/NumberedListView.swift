//
//  NumberedListView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct NumberedListView: View {
    // MARK: - Properties

    let items: [MarkdownOrderedListItem]

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                numberedItemRow(item)
            }
        }
    }
}

// MARK: - Private

private extension NumberedListView {
    func numberedItemRow(_ item: MarkdownOrderedListItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(item.number).")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.appAccent)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.leading, CGFloat(item.depth) * 16)

            Text(attributedContent(for: item.content))
                .font(.body)
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    VStack(alignment: .leading, spacing: 16) {
        NumberedListView(items: [
            MarkdownOrderedListItem(number: 1, content: "First step", depth: 0),
            MarkdownOrderedListItem(number: 2, content: "Second step", depth: 0),
            MarkdownOrderedListItem(number: 3, content: "Third step", depth: 0)
        ])

        NumberedListView(items: [
            MarkdownOrderedListItem(number: 1, content: "Main task", depth: 0),
            MarkdownOrderedListItem(number: 1, content: "Subtask A", depth: 1),
            MarkdownOrderedListItem(number: 2, content: "Subtask B", depth: 1),
            MarkdownOrderedListItem(number: 2, content: "Another main task with **bold**", depth: 0)
        ])
    }
    .padding()
}
