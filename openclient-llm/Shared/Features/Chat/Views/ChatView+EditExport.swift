//
//  ChatView+EditExport.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Phase 6: Regenerate, Edit, Export helpers

extension ChatView {
    @ViewBuilder
    func regenerateBar(
        _ loadedState: ChatViewModel.LoadedState,
        viewModel: ChatViewModel
    ) -> some View {
        if !loadedState.isStreaming,
           !loadedState.messages.isEmpty,
           loadedState.messages.last?.role == .assistant,
           loadedState.conversation != nil {
            Button {
                viewModel.send(.regenerateLastResponse)
            } label: {
                Label(String(localized: "Regenerate Response"), systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
        }
    }

    func editMessageSheet(
        _ message: ChatMessage,
        viewModel: ChatViewModel,
        editingMessage: Binding<ChatMessage?>,
        editingMessageText: Binding<String>
    ) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: editingMessageText)
                    .font(.body)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .frame(minHeight: 120)
            }
            .padding()
            .navigationTitle(String(localized: "Edit Message"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        editingMessage.wrappedValue = nil
                        editingMessageText.wrappedValue = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Resend")) {
                        let content = editingMessageText.wrappedValue
                        viewModel.send(.editMessage(id: message.id, newContent: content))
                        editingMessage.wrappedValue = nil
                        editingMessageText.wrappedValue = ""
                    }
                    .disabled(editingMessageText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .scrollDismissesKeyboard(.interactively)
    }

    func makeExportURL(_ loadedState: ChatViewModel.LoadedState) -> URL? {
        guard let conversation = loadedState.conversation else { return nil }
        guard let data = try? ExportConversationUseCase().execute(conversation) else { return nil }
        let raw = conversation.title.isEmpty ? "conversation" : conversation.title
        let sanitized = raw
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "_", options: .regularExpression)
            .prefix(50)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(String(sanitized))
            .appendingPathExtension("json")
        try? data.write(to: url)
        return url
    }
}
