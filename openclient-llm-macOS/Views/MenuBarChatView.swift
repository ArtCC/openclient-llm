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
    var onAuthorizationStateChanged: (Bool) -> Void = { _ in }

    @State private var chatId = UUID()
    @State private var viewModel = ChatViewModel()

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ChatView(
                isMenuBarPresentation: true,
                presentsMCPAuthorization: false,
                viewModel: viewModel
            )
                .id(chatId)
        }
        .frame(width: 380, height: 540)
        .mcpToolAuthorizationPresentation(viewModel: viewModel, compact: true)
        .onChange(of: viewModel.mcpAuthorizationCoordinator.pendingBatch != nil, initial: true) { _, isPending in
            onAuthorizationStateChanged(isPending)
        }
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
            Button {
                viewModel.send(.stopStreamingTapped)
                viewModel = ChatViewModel()
                chatId = UUID()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "New Chat"))
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
