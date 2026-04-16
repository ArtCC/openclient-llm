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
    @State private var showFavouritesSheet: Bool = false
    @State private var showMediaGallery: Bool = false
    @State private var scrollToMessageId: UUID?
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
                Menu {
                    if case .loaded(let loadedSt) = viewModel.state {
                        menuContent(for: loadedSt)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "More Options"))
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
        .sheet(isPresented: $showFavouritesSheet) {
            if case .loaded(let loadedSt) = viewModel.state {
                ChatFavouritesView(
                    messages: loadedSt.messages,
                    onMessageSelected: { id in scrollToMessageId = id }
                )
#if os(macOS)
                .frame(width: 500, height: 460)
#endif
            }
        }
        .sheet(isPresented: $showMediaGallery) {
            if case .loaded(let loadedSt) = viewModel.state {
                MediaFilesGalleryView(messages: loadedSt.messages) { scrollToMessageId = $0 }
#if os(macOS)
                    .frame(width: 500, height: 460)
#endif
            }
        }
        .sheet(item: $editingMessage) { message in
            editMessageSheet(
                message,
                viewModel: viewModel,
                editingMessage: $editingMessage,
                editingMessageText: $editingMessageText
            )
        }
        .imagePicker(isPresented: $showImagePicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
        }
        .documentPicker(isPresented: $showDocumentPicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
        }
        .imageFilePicker(isPresented: $showImageFilePicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
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
                    Menu {
                        if case .loaded(let loadedSt) = viewModel.state {
                            menuContent(for: loadedSt)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(String(localized: "More Options"))
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
            .sheet(isPresented: $showFavouritesSheet) {
                if case .loaded(let loadedSt) = viewModel.state {
                    ChatFavouritesView(
                        messages: loadedSt.messages,
                        onMessageSelected: { id in scrollToMessageId = id }
                    )
                }
            }
            .sheet(isPresented: $showMediaGallery) {
                if case .loaded(let loadedSt) = viewModel.state {
                    MediaFilesGalleryView(messages: loadedSt.messages) { scrollToMessageId = $0 }
                }
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
        .imagePicker(isPresented: $showImagePicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
        }
        .documentPicker(isPresented: $showDocumentPicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
        }
#if os(iOS)
        .cameraPicker(isPresented: $showCameraPicker) { data, fileName, type in
            viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
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
                    attachmentPreview(loadedState, send: { viewModel.send($0) })
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
                        onWebSearchToggled: { viewModel.send(.webSearchToggled) },
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
            .onChange(of: scrollToMessageId) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .center) }
                scrollToMessageId = nil
            }
            .task(id: loadedState.messages.isEmpty) {
                guard !loadedState.messages.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("scroll-bottom") }
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
                    } : nil,
                    onFavouriteTapped: {
                        viewModel.send(.toggleFavourite(message.id))
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

    // MARK: - Menu Content

    @ViewBuilder
    func menuContent(for loadedSt: ChatViewModel.LoadedState) -> some View {
        ForEach(menuActions(for: loadedSt)) { action in
            switch action {
            case .export(let url):
                ShareLink(item: url) {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .favourites:
                Button { showFavouritesSheet = true } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .mediaFiles:
                Button { showMediaGallery = true } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .modelParameters:
                Button { showModelParametersSheet = true } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .systemPrompt:
                Button { showSystemPromptSheet = true } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
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

}

#Preview {
    ChatView()
}
