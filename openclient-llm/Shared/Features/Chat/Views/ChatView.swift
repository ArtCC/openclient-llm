//
//  ChatView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
    // MARK: - Properties

    @State private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var isAtBottom: Bool = true

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
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    modelSelector
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
    func loadedView(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        VStack(spacing: 0) {
            messagesScrollView(loadedState)
            errorBanner(loadedState.errorMessage)
            inputBar(loadedState)
        }
    }

    // MARK: - Messages

    func messagesScrollView(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if loadedState.messages.isEmpty {
                    emptyState(loadedState)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(loadedState.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isStreaming: loadedState.isStreaming
                                && message.id
                                == loadedState.messages.last?.id
                            )
                            .id(message.id)
                            .transition(.opacity)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("scroll-bottom")
                    }
                    .padding(.horizontal, 16)
                    .animation(
                        .spring(duration: 0.3),
                        value: loadedState.messages.count
                    )
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height
                    - geometry.contentOffset.y
                    - geometry.containerSize.height < 80
            } action: { _, newValue in
                isAtBottom = newValue
            }
            .onChange(of: loadedState.messages.count) {
                isAtBottom = true
                withAnimation(.smooth) {
                    proxy.scrollTo("scroll-bottom")
                }
            }
            .onChange(of: loadedState.messages.last?.content) {
                guard isAtBottom else { return }
                proxy.scrollTo("scroll-bottom")
            }
#if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { _ in
                guard isAtBottom else { return }
                withAnimation(.smooth) {
                    proxy.scrollTo("scroll-bottom")
                }
            }
#endif
        }
    }

    // MARK: - Empty State

    func emptyState(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(
                    String(localized: "How can I help you?")
                )
                .font(.title2)
                .fontWeight(.semibold)

                if loadedState.selectedModel == nil {
                    Text(
                        String(
                            localized:
                                "Select a model to start chatting"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if loadedState.selectedModel != nil {
                suggestionChipsGrid(loadedState)
            }

            Spacer()
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding()
    }

    func suggestionChipsGrid(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 12
        ) {
            ForEach(
                loadedState.conversationStarters
            ) { starter in
                Button {
                    viewModel.send(.suggestionTapped(starter.text))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: starter.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(starter.text)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 14)
                )
            }
        }
    }

    // MARK: - Error Banner

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

    // MARK: - Input Bar

    func inputBar(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        HStack(spacing: 8) {
            TextField(
                String(localized: "Message..."),
                text: $inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
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

            actionButton(loadedState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    func actionButton(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        if loadedState.isStreaming {
            Button {
                viewModel.send(.stopStreamingTapped)
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Stop"))
            .transition(.scale.combined(with: .opacity))
        } else {
            let hasText = !loadedState.inputText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            let hasModel = loadedState.selectedModel != nil

            if hasText && hasModel {
                Button {
                    viewModel.send(.sendTapped)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Send"))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Model Selector

    @ViewBuilder
    var modelSelector: some View {
        if case .loaded(let loadedState) = viewModel.state,
           !loadedState.availableModels.isEmpty {
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
                    Text(
                        loadedState.selectedModel?.id
                        ?? String(localized: "No Model")
                    )
                    .font(.headline)
                    .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers
}

#Preview {
    ChatView()
}
