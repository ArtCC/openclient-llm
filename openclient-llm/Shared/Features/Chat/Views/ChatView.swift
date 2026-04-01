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
    @State private var audioRecorder = AudioRecorderManager()

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
}

// MARK: - Private

private extension ChatView {
    func loadedView(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        messagesScrollView(loadedState)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    errorBanner(loadedState.errorMessage)
                    attachmentPreview(loadedState)
                    inputBar(loadedState)
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

    // MARK: - Input Bar

    func inputBar(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        HStack(spacing: 8) {
            attachmentButton(loadedState)

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
                inputText = ""
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
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    func attachmentButton(_ loadedState: ChatViewModel.LoadedState) -> some View {
        Menu {
#if os(iOS)
            Button {
                showCameraPicker = true
            } label: {
                Label(String(localized: "Camera"), systemImage: "camera")
            }
#endif

            Button {
                showDocumentPicker = true
            } label: {
                Label(String(localized: "Document"), systemImage: "doc")
            }

            Button {
                showImagePicker = true
            } label: {
                Label(String(localized: "Photo Library"), systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func actionButton(
        _ loadedState: ChatViewModel.LoadedState
    ) -> some View {
        if loadedState.isStreaming {
            stopStreamingButton
        } else if loadedState.isTranscribing {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 44, minHeight: 44)
                .transition(.scale.combined(with: .opacity))
        } else if audioRecorder.isRecording {
            stopRecordingButton
        } else {
            let hasText = !loadedState.inputText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            let hasModel = loadedState.selectedModel != nil
            let hasAttachments = !loadedState.pendingAttachments.isEmpty
            let hasTranscriptionModel = loadedState.transcriptionModelId != nil

            if (hasText || hasAttachments) && hasModel {
                sendButton
            } else if hasModel && hasTranscriptionModel {
                micButton
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
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Recording helpers

    func startRecording() {
        audioRecorder.startRecording()
    }

    func stopRecording() {
        audioRecorder.stopRecording { data, duration in
            guard let data else { return }
            viewModel.send(.audioRecorded(data, duration))
        }
    }

    // MARK: - Action Buttons

    var stopStreamingButton: some View {
        Button { viewModel.send(.stopStreamingTapped) } label: {
            Image(systemName: "stop.circle.fill").font(.title).foregroundStyle(.red)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Stop"))
        .transition(.scale.combined(with: .opacity))
    }

    var stopRecordingButton: some View {
        Button { stopRecording() } label: {
            Image(systemName: "stop.circle.fill").font(.title).foregroundStyle(.red)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Stop Recording"))
        .transition(.scale.combined(with: .opacity))
    }

    var sendButton: some View {
        Button { inputText = ""; viewModel.send(.sendTapped) } label: {
            Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Color.accentColor)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Send"))
        .transition(.scale.combined(with: .opacity))
    }

    var micButton: some View {
        Button { startRecording() } label: {
            Image(systemName: "mic.circle.fill").font(.title).foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Record Audio"))
        .transition(.scale.combined(with: .opacity))
    }

}

#Preview {
    ChatView()
}
