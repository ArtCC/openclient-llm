//
//  ChatView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import TipKit

struct ChatView: View {
    // MARK: - Properties

    @State var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var shouldAutoScroll: Bool = true
    @State private var isNearBottom: Bool = true
    @State private var isAtBottom: Bool = true
    @State private var isNearTop: Bool = true
    @State private var scrollPosition = ScrollPosition(idType: UUID.self)
    @State private var visibleMessageIds: [UUID] = []
    @State private var isManuallyScrolling: Bool = false
    @State private var showSystemPromptSheet: Bool = false
    @State private var showModelParametersSheet: Bool = false
    @State private var showFavouritesSheet: Bool = false
    @State private var showMediaGallery: Bool = false
    @State private var scrollToMessageId: UUID?
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showImageFilePicker: Bool = false
    @State var showMCPSheet: Bool = false
    @State private var showActions: Bool = false
    @State var editingMessage: ChatMessage?
    @State var editingMessageText: String = ""

    var conversation: Conversation?
    var isPrivateChat: Bool
    var shareItem: ShareExtensionItem?
    var urlSchemeText: String?
    var onConversationUpdated: (() -> Void)?
    var onForkCreated: ((Conversation) -> Void)?
    var onShareItemProcessed: (() -> Void)?
    var onURLSchemeTextProcessed: (() -> Void)?
    var isMenuBarPresentation: Bool
    var presentsMCPAuthorization: Bool
    private let appReviewManager: AppReviewManagerProtocol

    // MARK: - Init

    init(
        conversation: Conversation? = nil,
        isPrivateChat: Bool = false,
        shareItem: ShareExtensionItem? = nil,
        urlSchemeText: String? = nil,
        appReviewManager: AppReviewManagerProtocol = AppReviewManager(),
        isMenuBarPresentation: Bool = false,
        presentsMCPAuthorization: Bool = true,
        viewModel: ChatViewModel? = nil,
        onConversationUpdated: (() -> Void)? = nil,
        onForkCreated: ((Conversation) -> Void)? = nil,
        onShareItemProcessed: (() -> Void)? = nil,
        onURLSchemeTextProcessed: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel ?? ChatViewModel(
            conversation: conversation,
            isPrivateChat: isPrivateChat
        ))
        self.conversation = conversation
        self.isPrivateChat = isPrivateChat
        self.shareItem = shareItem
        self.urlSchemeText = urlSchemeText
        self.appReviewManager = appReviewManager
        self.isMenuBarPresentation = isMenuBarPresentation
        self.presentsMCPAuthorization = presentsMCPAuthorization
        self.onConversationUpdated = onConversationUpdated
        self.onForkCreated = onForkCreated
        self.onShareItemProcessed = onShareItemProcessed
        self.onURLSchemeTextProcessed = onURLSchemeTextProcessed
    }

    // MARK: - View

    var body: some View {
#if os(macOS)
        macOSBody.mcpToolAuthorizationPresentation(
            viewModel: viewModel,
            compact: isMenuBarPresentation,
            isEnabled: presentsMCPAuthorization
        )
#else
        iOSBody.mcpToolAuthorizationPresentation(
            viewModel: viewModel,
            compact: false,
            isEnabled: presentsMCPAuthorization
        )
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
                    .tint(.secondary)
            case .loaded(let loadedState):
                loadedView(loadedState)
            }
        }
        .navigationTitle(conversation?.title ?? "")
        .tint(Color.appAccent)
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
                .popoverTip(chatOptionsTip)
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
            .sheet(isPresented: $showMCPSheet, content: mcpToolsSheet)
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
            await processShareItemIfNeeded(
                viewModel: viewModel,
                shareItem: shareItem,
                onShareItemProcessed: onShareItemProcessed
            )
            await processURLSchemeTextIfNeeded(
                viewModel: viewModel,
                urlSchemeText: urlSchemeText,
                onURLSchemeTextProcessed: onURLSchemeTextProcessed
            )
        }
        .onChange(of: conversation) { _, newConversation in
            if let newConversation {
                viewModel.send(.conversationLoaded(newConversation))
            }
        }
        .onDisappear(perform: handleViewDisappeared)
    }
#endif

    var iOSBody: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                    .tint(.secondary)
                case .loaded(let loadedState):
                    loadedView(loadedState)
                }
            }
            .navigationTitle("")
            .tint(Color.appAccent)
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
                    .popoverTip(chatOptionsTip)
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
            .sheet(isPresented: $showMCPSheet, content: mcpToolsSheet)
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
            await processShareItemIfNeeded(
                viewModel: viewModel,
                shareItem: shareItem,
                onShareItemProcessed: onShareItemProcessed
            )
            await processURLSchemeTextIfNeeded(
                viewModel: viewModel,
                urlSchemeText: urlSchemeText,
                onURLSchemeTextProcessed: onURLSchemeTextProcessed
            )
        }
        .onChange(of: conversation) { _, newConversation in
            if let newConversation {
                viewModel.send(.conversationLoaded(newConversation))
            }
        }
        .onDisappear(perform: handleViewDisappeared)
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
                        onSend: {
                            viewModel.send(.sendTapped)
                            showActions = false
                        },
                        onStopStreaming: { viewModel.send(.stopStreamingTapped) },
                        onStartRecording: { viewModel.send(.startRecordingTapped) },
                        onStopRecording: { viewModel.send(.stopRecordingTapped) },
                        onCancelRecording: { viewModel.send(.cancelRecordingTapped) },
                        onWebSearchToggled: { viewModel.send(.webSearchToggled) },
                        onMCPButtonTapped: {
                            showMCPSheet = true
                            viewModel.send(.mcpButtonTapped)
                            showActions = false
                        },
                        showActions: $showActions,
                        showImageFilePicker: $showImageFilePicker
                    )
                }
            }
            .modifier(ChatDropModifier(
                onText: { viewModel.send(.inputChanged($0)) },
                onAttachment: {
                    AppTips.chatAttachments.invalidate(reason: .actionPerformed)
                    viewModel.send(.attachmentAdded(data: $0, fileName: $1, type: $2))
                }
            ))
    }

    func handleViewDisappeared() {
        viewModel.send(.viewDisappeared)
        appReviewManager.requestReview()
    }

    // MARK: - Messages

    func messagesScrollView(_ loadedState: ChatViewModel.LoadedState) -> some View {
        scrollContent(loadedState)
            .overlay(alignment: .top) {
                if isManuallyScrolling,
                   let date = visibleMessageDate(in: loadedState.messages, visibleMessageIds: visibleMessageIds) {
                    floatingDateLabel(date)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !isNearTop && !loadedState.messages.isEmpty {
                    scrollAnchorButton(isTop: true) {
                        shouldAutoScroll = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scrollPosition.scrollTo(edge: .top)
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if (!isNearBottom || !shouldAutoScroll) && !loadedState.messages.isEmpty {
                    scrollAnchorButton(isTop: false) {
                        shouldAutoScroll = true
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scrollPosition.scrollTo(edge: .bottom)
                        }
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearTop)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearBottom)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldAutoScroll)
            .animation(.easeInOut(duration: 0.2), value: isManuallyScrolling)
    }

    func scrollContent(_ loadedState: ChatViewModel.LoadedState) -> some View {
        scrollViewContent(loadedState)
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentSize.height - $0.contentOffset.y - $0.containerSize.height < 150
            } action: { _, new in isNearBottom = new }
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentSize.height - $0.contentOffset.y - $0.containerSize.height < 8
            } action: { _, new in isAtBottom = new }
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentOffset.y < 150
            } action: { _, new in isNearTop = new }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .interacting {
                    shouldAutoScroll = false
                    isManuallyScrolling = true
                } else if newPhase == .idle {
                    if oldPhase != .animating {
                        shouldAutoScroll = isAtBottom
                    }
                    isManuallyScrolling = false
                }
            }
            .modifier(ScrollTriggerModifier(
                scrollPosition: $scrollPosition,
                scrollToMessageId: $scrollToMessageId,
                shouldAutoScroll: $shouldAutoScroll,
                loadedState: loadedState
            ))
    }

    func scrollViewContent(_ loadedState: ChatViewModel.LoadedState) -> some View {
        ScrollView {
            if loadedState.messages.isEmpty {
                ChatEmptyStateView(
                    selectedModel: loadedState.selectedModel,
                    conversationStarters: loadedState.conversationStarters,
                    isPrivateChat: isPrivateChat,
                    onSuggestionTapped: { viewModel.send(.suggestionTapped($0)) }
                )
            } else {
                messagesList(loadedState)
            }
        }
        .scrollPosition($scrollPosition)
        .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.01) {
            visibleMessageIds = $0
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#elseif os(macOS)
        .contentMargins(.top, 16, for: .scrollContent)
#endif
    }

    // MARK: - Menu Content

    @ViewBuilder
    func menuContent(for loadedSt: ChatViewModel.LoadedState) -> some View {
        ForEach(menuActions(for: loadedSt)) { action in
            switch action {
            case .export:
                if let exportedData = loadedSt.exportedData,
                   let exportedText = String(data: exportedData, encoding: .utf8) {
                    ShareLink(item: exportedText) {
                        Label(action.title, systemImage: action.systemImage)
                    }
                } else {
                    Button {
                        AppTips.chatOptions.invalidate(reason: .actionPerformed)
                        viewModel.send(.exportConversation)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            case .favourites:
                Button {
                    AppTips.chatOptions.invalidate(reason: .actionPerformed)
                    showFavouritesSheet = true
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .mediaFiles:
                Button {
                    AppTips.chatOptions.invalidate(reason: .actionPerformed)
                    showMediaGallery = true
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .modelParameters:
                Button {
                    AppTips.chatOptions.invalidate(reason: .actionPerformed)
                    showModelParametersSheet = true
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .systemPrompt:
                Button {
                    AppTips.chatOptions.invalidate(reason: .actionPerformed)
                    showSystemPromptSheet = true
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
    }

}
#Preview { ChatView() }
