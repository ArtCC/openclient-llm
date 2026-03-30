//
//  ChatView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatView: View {
    // MARK: - Properties

    @State private var viewModel = ChatViewModel()
    @State private var inputText: String = ""

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let loadedState):
                    loadedView(loadedState)
                }
            }
            .navigationTitle(String(localized: "Chat"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    modelPicker
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ChatView {
    func loadedView(_ loadedState: ChatViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            messagesScrollView(loadedState)
            errorBanner(loadedState.errorMessage)
            inputBar(loadedState)
        }
    }

    func messagesScrollView(_ loadedState: ChatViewModel.LoadedState) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if loadedState.messages.isEmpty {
                    emptyState(loadedState)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(loadedState.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if loadedState.isStreaming {
                            streamingIndicator
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: loadedState.messages.last?.content) {
                scrollToBottom(proxy: proxy, loadedState: loadedState)
            }
        }
    }

    func emptyState(_ loadedState: ChatViewModel.LoadedState) -> some View {
        ContentUnavailableView {
            Label(String(localized: "No Messages"), systemImage: "bubble.left.and.bubble.right")
        } description: {
            if loadedState.selectedModel != nil {
                Text(String(localized: "Send a message to start a conversation."))
            } else {
                Text(String(localized: "No models available. Check your server configuration."))
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    func errorBanner(_ errorMessage: String?) -> some View {
        if let errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(errorMessage)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
        }
    }

    func inputBar(_ loadedState: ChatViewModel.LoadedState) -> some View {
        HStack(spacing: 12) {
            TextField(
                String(localized: "Type a message..."),
                text: $inputText,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .textSelection(.enabled)
            .lineLimit(1...5)
            #if os(iOS)
            .submitLabel(.send)
            #endif
            .onSubmit {
                viewModel.send(.sendTapped)
            }
            .onChange(of: inputText) { _, newValue in
                viewModel.send(.inputChanged(newValue))
            }
            .onChange(of: loadedState.inputText) { _, newValue in
                if newValue != inputText {
                    inputText = newValue
                }
            }

            Button {
                viewModel.send(.sendTapped)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(
                loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || loadedState.isStreaming
                    || loadedState.selectedModel == nil
            )
            .accessibilityLabel(String(localized: "Send"))
        }
        .padding()
    }

    var streamingIndicator: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "Generating..."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    var modelPicker: some View {
        if case .loaded(let loadedState) = viewModel.state, !loadedState.availableModels.isEmpty {
            Menu {
                ForEach(loadedState.availableModels) { model in
                    Button {
                        viewModel.send(.modelSelected(model))
                    } label: {
                        HStack {
                            Text(model.id)
                            if model == loadedState.selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text(loadedState.selectedModel?.id ?? String(localized: "No Model"))
                        .lineLimit(1)
                }
                .font(.caption)
            }
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy, loadedState: ChatViewModel.LoadedState) {
        guard let lastMessage = loadedState.messages.last else { return }
        withAnimation(.smooth) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

#Preview {
    ChatView()
}
