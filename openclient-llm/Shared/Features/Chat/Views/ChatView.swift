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
    @State private var isNearTop: Bool = true
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    @State private var showSystemPromptSheet: Bool = false
    @State private var showModelParametersSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showImageFilePicker: Bool = false
    @State private var editingMessage: ChatMessage?
    @State private var editingMessageText: String = ""

    var conversation: Conversation?
    var onConversationUpdated: (() -> Void)?
    var onForkCreated: ((Conversation) -> Void)?

    // MARK: - Init

    init(
        conversation: Conversation? = nil,
        onConversationUpdated: (() -> Void)? = nil,
        onForkCreated: ((Conversation) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: ChatViewModel(conversation: conversation))
        self.conversation = conversation
        self.onConversationUpdated = onConversationUpdated
        self.onForkCreated = onForkCreated
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
                modelSelector(using: viewModel)
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    if case .loaded(let loadedSt) = viewModel.state,
                       loadedSt.conversation != nil, !loadedSt.messages.isEmpty,
                       let url = makeExportURL(loadedSt) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(String(localized: "Export Conversation"))
                    }

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
        .sheet(item: $editingMessage) { message in
            editMessageSheet(
                message,
                viewModel: viewModel,
                editingMessage: $editingMessage,
                editingMessageText: $editingMessageText
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
                    modelSelector(using: viewModel)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        if case .loaded(let loadedSt) = viewModel.state,
                           loadedSt.conversation != nil, !loadedSt.messages.isEmpty,
                           let url = makeExportURL(loadedSt) {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel(String(localized: "Export Conversation"))
                        }

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
            .sheet(item: $editingMessage) { message in
                editMessageSheet(
                    message,
                    viewModel: viewModel,
                    editingMessage: $editingMessage,
                    editingMessageText: $editingMessageText
                )
            }
        }
        .task {
            viewModel.onConversationUpdated = onConversationUpdated
            viewModel.onForkCreated = onForkCreated
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
                        onStartRecording: { viewModel.send(.startRecordingTapped) },
                        onStopRecording: { viewModel.send(.stopRecordingTapped) },
                        onCancelRecording: { viewModel.send(.cancelRecordingTapped) },
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
                .overlay(alignment: .topTrailing) {
                    if !isNearTop && !loadedState.messages.isEmpty {
                        scrollAnchorButton(isTop: true) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                scrollPosition.scrollTo(edge: .top)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !isNearBottom && !loadedState.messages.isEmpty {
                        scrollAnchorButton(isTop: false) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                scrollPosition.scrollTo(edge: .bottom)
                            }
                            shouldAutoScroll = true
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearTop)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearBottom)
        }
    }

    func scrollContent(
        _ loadedState: ChatViewModel.LoadedState,
        proxy: ScrollViewProxy
    ) -> some View {
        scrollViewContent(loadedState)
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentSize.height - $0.contentOffset.y - $0.containerSize.height < 150
            } action: { _, new in isNearBottom = new }
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentOffset.y < 150
            } action: { _, new in isNearTop = new }
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
            .task(id: loadedState.messages.isEmpty) {
                guard !loadedState.messages.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("scroll-bottom")
                }
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
        .scrollPosition($scrollPosition)
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
            Color.clear
                .frame(height: 1)
                .id("scroll-top")
            ForEach(loadedState.messages) { message in
                let isLast = message.id == loadedState.messages.last?.id
                MessageBubbleView(
                    message: message,
                    isStreaming: loadedState.isStreaming && isLast,
                    isSpeaking: loadedState.speakingMessageId == message.id,
                    hasTTS: loadedState.ttsModelId != nil,
                    showTokenUsage: loadedState.showTokenUsage,
                    isLastMessage: isLast,
                    onSpeakTapped: {
                        viewModel.send(.speakMessageTapped(message))
                    },
                    onStopSpeakingTapped: {
                        viewModel.send(.stopSpeakingTapped)
                    },
                    onEditTapped: message.role == .user ? {
                        editingMessage = message
                        editingMessageText = message.content
                    } : nil,
                    onRegenerateTapped: (message.role == .assistant && isLast) ? {
                        viewModel.send(.regenerateLastResponse)
                    } : nil,
                    onForkTapped: loadedState.conversation != nil ? {
                        viewModel.send(.forkFromMessage(message.id))
                    } : nil
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

    // MARK: - Scroll Navigation

    func scrollAnchorButton(isTop: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isTop ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(isTop ? .top : .bottom, 16)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
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
}

#Preview {
    ChatView()
}
