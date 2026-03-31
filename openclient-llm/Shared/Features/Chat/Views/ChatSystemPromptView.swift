//
//  ChatSystemPromptView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatSystemPromptView: View {
    // MARK: - Properties

    var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    // MARK: - View

    var body: some View {
        NavigationStack {
            editor
                .navigationTitle(String(localized: "System Prompt"))
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done")) {
                            isPresented = false
                        }
                    }
                }
        }
#if os(macOS)
        .frame(width: 500, height: 400)
#endif
    }
}

// MARK: - Private

private extension ChatSystemPromptView {
    @ViewBuilder
    var editor: some View {
        if case .loaded(let loadedState) = viewModel.state {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Set instructions for the assistant's behavior in this conversation."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: Binding(
                    get: { loadedState.systemPrompt },
                    set: { viewModel.send(.systemPromptChanged($0)) }
                ))
                .font(.body)
#if os(macOS)
                .frame(minHeight: 200)
#endif
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
}

#Preview {
    ChatSystemPromptView(
        viewModel: ChatViewModel(),
        isPresented: .constant(true)
    )
}
