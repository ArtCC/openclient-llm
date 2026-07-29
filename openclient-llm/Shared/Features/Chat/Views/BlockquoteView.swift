//
//  BlockquoteView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct BlockquoteView: View {
    // MARK: - Properties

    let content: String

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.appAccent.opacity(0.5))
                .frame(width: 3)

            Text(attributedContent)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
        }
    }
}

// MARK: - Private

private extension BlockquoteView {
    var attributedContent: AttributedString {
        if let result = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return result
        }
        return AttributedString(content)
    }
}

#Preview {
    VStack(spacing: 16) {
        BlockquoteView(content: "This is a simple blockquote with a single line.")
        BlockquoteView(content: "This is a **bold** blockquote with *italic* and `inline code`.")
        BlockquoteView(
            content: "This is a longer blockquote that spans\n"
                + "multiple lines to demonstrate\n"
                + "how the view handles wrapping."
        )
    }
    .padding()
}
