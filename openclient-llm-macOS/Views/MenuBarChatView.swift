//
//  MenuBarChatView.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - View

struct MenuBarChatView: View {
    // MARK: - Properties

    var onOpenInApp: () -> Void

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ChatView()
        }
        .frame(width: 380, height: 540)
    }
}

// MARK: - Private

private extension MenuBarChatView {
    var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
            Text(String(localized: "OpenClient"))
                .font(.headline)
            Spacer()
            Button {
                onOpenInApp()
            } label: {
                Label(String(localized: "Open in App"), systemImage: "arrow.up.forward.app")
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    MenuBarChatView(onOpenInApp: {})
        .frame(width: 380, height: 540)
}
