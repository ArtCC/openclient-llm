//
//  CodeBlockView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CodeBlockView: View {
    // MARK: - Properties

    let code: String
    let language: String?

    @State private var copied = false

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .overlay(Color.primary.opacity(0.1))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Private

private extension CodeBlockView {
    var header: some View {
        HStack {
            Text(language ?? String(localized: "Code"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                copyCode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                    Text(copied ? String(localized: "Copied") : String(localized: "Copy"))
                        .font(.caption)
                }
                .foregroundStyle(copied ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    func copyCode() {
#if os(iOS)
        UIPasteboard.general.string = code
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
#endif
        withAnimation(.easeInOut(duration: 0.15)) {
            copied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.15)) {
                copied = false
            }
        }
    }
}

#Preview {
    CodeBlockView(
        code: "func hello() -> String {\n    return \"Hello, world!\"\n}",
        language: "swift"
    )
    .padding()
}
