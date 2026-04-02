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

    @State private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var shouldAutoScroll: Bool = true
    @State private var isNearBottom: Bool = true
    @State private var showSystemPromptSheet: Bool = false
    @State private var showModelParametersSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showImageFilePicker: Bool = false

    var conversation: Conversation?
    var onConversationUpdated: (() -> Void)?

    // MARK: - Init

    init(conversation: Conversation? = nil, onConversationUpdated: (() -> Void)? = nil) {
        _viewModel = State(initialValue: ChatViewModel(conversation: conversation))
        self.conversation = conversation
        self.onConversationUpdated = onConversationUpdated
    }

    // MARK: - View

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }
}

// MARK: - Private

private extension ChatView {
    #if os(macOS)
    var macOSBody: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let loadedState):
                loadedView(loadedState)
            }
        }
        .navigationTitle(conversation?.title ?? "")
        .toolbar {
            ToolbarItem(placement: .principal) {
                modelSelector
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button {
                        showModelParametersSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(String(localized: "Model Parameters"))

                    Button {
                        showSystemPromptSheet = true
                    } label: {
                        Image(systemName: "text.bubble")
                    }
                    .accessibilityLabel(String(localized: "System Prompt"))
                }
            }
        }
        .sheet(isPresented: $showSystemPromptSheet) {
            ChatSystemPromptView(
                viewModel: viewModel,
                isPresented: $showSystemPromptSheet
            )
        }
        .sheet(isPresented: $showModelParametersSheet) {
            ChatModelParametersView(
                viewModel: viewModel,
                isPresented: $showModelParametersSheet
            )
        }
        .imagePicker(isPresented: $showImagePicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
        .documentPicker(isPresented: $showDocumentPicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
        .imageFilePicker(isPresented: $showImageFilePicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
        .task {
            viewModel.onConversationUpdated = onConversationUpdated
            viewModel.send(.viewAppeared)
        }
        .onChange(of: conversation) { _, newConversation in
            if let newConversation {
                viewModel.send(.conversationLoaded(newConversation))
            }
        }
    }
    #endif

    var iOSBody: some View {
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
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        Button {
                            showModelParametersSheet = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel(String(localized: "Model Parameters"))

                        Button {
                            showSystemPromptSheet = true
                        } label: {
                            Image(systemName: "text.bubble")
                        }
                        .accessibilityLabel(String(localized: "System Prompt"))
                    }
                }
            }
            .sheet(isPresented: $showSystemPromptSheet) {
                ChatSystemPromptView(
                    viewModel: viewModel,
                    isPresented: $showSystemPromptSheet
                )
            }
            .sheet(isPresented: $showModelParametersSheet) {
                ChatModelParametersView(
                    viewModel: viewModel,
                    isPresented: $showModelParametersSheet
                )
            }
        }
        .task {
            viewModel.onConversationUpdated = onConversationUpdated
            viewModel.send(.viewAppeared)
        }
        .onChange(of: conversation) { _, newConversation in
            if let newConversation {
                viewModel.send(.conversationLoaded(newConversation))
            }
        }
        .imagePicker(isPresented: $showImagePicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
        .documentPicker(isPresented: $showDocumentPicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
#if os(iOS)
        .cameraPicker(isPresented: $showCameraPicker) { attachment in
            viewModel.send(.attachmentAdded(attachment))
        }
#endif
    }
    func loadedView(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        messagesScrollView(loadedState)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    errorBanner(loadedState.errorMessage)
                    attachmentPreview(loadedState)
                    ChatInputBarView(
                        inputText: $inputText,
                        showImagePicker: $showImagePicker,
                        showDocumentPicker: $showDocumentPicker,
                        showCameraPicker: $showCameraPicker,
                        loadedState: loadedState,
                        onInputChanged: { viewModel.send(.inputChanged($0)) },
                        onSend: { viewModel.send(.sendTapped) },
                        onStopStreaming: { viewModel.send(.stopStreamingTapped) },
                        onAudioRecorded: { data, duration in viewModel.send(.audioRecorded(data, duration)) },
                        showImageFilePicker: $showImageFilePicker
                    )
                }
            }
    }

    // MARK: - Messages

    func messagesScrollView(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        ScrollViewReader { proxy in
            scrollContent(loadedState, proxy: proxy)
        }
    }

    func scrollContent(
        _ loadedState: ChatViewModel.LoadedState,
        proxy: ScrollViewProxy
    ) -> some View {
        scrollViewContent(loadedState)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentSize.height - geo.contentOffset.y - geo.containerSize.height < 80
            } action: { _, newValue in
                isNearBottom = newValue
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .interacting {
                    shouldAutoScroll = false
                } else if newPhase == .idle, oldPhase != .animating {
                    shouldAutoScroll = isNearBottom
                }
            }
            .onChange(of: loadedState.messages.count) {
                shouldAutoScroll = true
                proxy.scrollTo("scroll-bottom")
            }
            .onChange(of: loadedState.messages.last?.content) {
                guard shouldAutoScroll else { return }
                proxy.scrollTo("scroll-bottom")
            }
            .onChange(of: loadedState.scrollToBottomTrigger) {
                proxy.scrollTo("scroll-bottom")
            }
#if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { notification in
                let duration = notification.userInfo?[
                    UIResponder.keyboardAnimationDurationUserInfoKey
                ] as? Double ?? 0.25
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    proxy.scrollTo("scroll-bottom")
                    shouldAutoScroll = true
                }
            }
#endif
    }

    func scrollViewContent(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        ScrollView {
            if loadedState.messages.isEmpty {
                ChatEmptyStateView(
                    selectedModel: loadedState.selectedModel,
                    conversationStarters: loadedState.conversationStarters,
                    onSuggestionTapped: { viewModel.send(.suggestionTapped($0)) }
                )
            } else {
                messagesList(loadedState)
            }
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#elseif os(macOS)
        .contentMargins(.top, 16, for: .scrollContent)
#endif
    }

    func messagesList(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(loadedState.messages) { message in
                MessageBubbleView(
                    message: message,
                    isStreaming: loadedState.isStreaming
                    && message.id
                    == loadedState.messages.last?.id,
                    isSpeaking: loadedState.speakingMessageId == message.id,
                    hasTTS: loadedState.ttsModelId != nil,
                    showTokenUsage: loadedState.showTokenUsage,
                    onSpeakTapped: {
                        viewModel.send(.speakMessageTapped(message))
                    },
                    onStopSpeakingTapped: {
                        viewModel.send(.stopSpeakingTapped)
                    }
                )
                .id(message.id)
                .transition(.opacity)
            }
            Color.clear
                .frame(height: 1)
                .id("scroll-bottom")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
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
            .background(Color.red.opacity(0.85))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Attachment Preview

    @ViewBuilder
    func attachmentPreview(_ loadedState: ChatViewModel.LoadedState) -> some View {
        if !loadedState.pendingAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(loadedState.pendingAttachments) { attachment in
                        attachmentThumbnail(attachment)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    func attachmentThumbnail(_ attachment: ChatMessage.Attachment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.type == .image ? "photo" : "doc.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(attachment.fileName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Button {
                viewModel.send(.attachmentRemoved(attachment.id))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
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
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ChatView()
}
