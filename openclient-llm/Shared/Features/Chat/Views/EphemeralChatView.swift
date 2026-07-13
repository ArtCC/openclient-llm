//
//  EphemeralChatView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct EphemeralChatView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EphemeralChatViewModel()
    @State private var inputText: String = ""
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showImageFilePicker: Bool = false

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let loadedState):
                    chatContent(loadedState)
                }
            }
            .navigationTitle(String(localized: "Private Chat"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        viewModel.send(.viewDisappeared)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    if case .loaded(let loadedState) = viewModel.state {
                        modelMenu(loadedState)
                    }
                }
            }
        }
        .task { viewModel.send(.viewAppeared) }
        .onDisappear { viewModel.send(.viewDisappeared) }
        .imagePicker(isPresented: $showImagePicker, onAttachmentData: addAttachment)
        .documentPicker(isPresented: $showDocumentPicker, onAttachmentData: addAttachment)
#if os(iOS)
        .cameraPicker(isPresented: $showCameraPicker, onAttachmentData: addAttachment)
#elseif os(macOS)
        .imageFilePicker(isPresented: $showImageFilePicker, onAttachmentData: addAttachment)
#endif
    }
}

// MARK: - Private

private extension EphemeralChatView {
    func chatContent(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        messages(loadedState)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    privacyNotice
                    errorBanner(loadedState.errorMessage)
                    pendingAttachments(loadedState.pendingAttachments)
                    inputBar(loadedState)
                }
                .padding(.top, 8)
                .background(.bar)
            }
    }

    func messages(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if loadedState.messages.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Private Chat"), systemImage: "lock.bubble")
                    } description: {
                        Text(String(localized: "This chat is only kept while this window is open."))
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(loadedState.messages) { message in
                        messageRow(message)
                    }
                }
            }
            .padding()
        }
    }

    func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            Text(message.content)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .padding(12)
                .background(message.role == .user ? Color.appAccent.opacity(0.18) : Color.secondary.opacity(0.12))
                .clipShape(.rect(cornerRadius: 16))
            attachmentContent(message.attachments)
        }
    }

    @ViewBuilder
    func attachmentContent(_ attachments: [ChatMessage.Attachment]) -> some View {
        if !attachments.isEmpty {
            ForEach(attachments) { attachment in
                if attachment.type == .image {
                    AttachmentImageView(attachment: attachment, thumbnailSize: 160)
                } else {
                    Label(attachment.fileName, systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func modelMenu(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
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
                Text(loadedState.selectedModel?.id ?? String(localized: "No Model"))
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(String(localized: "Select Model"))
    }

    var privacyNotice: some View {
        Label(privacyNoticeText, systemImage: "eye.slash")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    var privacyNoticeText: String {
        let localRetention = String(localized: "Messages, attachments, and memory are not saved locally.")
        let remoteProcessing = String(localized: "Your server and web providers may process sent data.")
        return "\(localRetention) \(remoteProcessing)"
    }

    @ViewBuilder
    func errorBanner(_ errorMessage: String?) -> some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    func pendingAttachments(_ attachments: [ChatMessage.Attachment]) -> some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(attachments) { attachment in
                        Button {
                            viewModel.send(.attachmentRemoved(attachment.id))
                        } label: {
                            Label(attachment.fileName, systemImage: attachment.type == .image ? "photo" : "doc.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    func inputBar(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            if loadedState.isSearchingWeb {
                Label(String(localized: "Searching the web…"), systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }
            HStack(spacing: 8) {
                attachmentMenu
                agentButton(loadedState)
                webSearchButton(loadedState)
                TextField(String(localized: "Message..."), text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .onChange(of: inputText) { _, text in viewModel.send(.inputChanged(text)) }
                    .onChange(of: loadedState.inputText) { _, text in inputText = text }
                actionButton(loadedState)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    var attachmentMenu: some View {
        Menu {
#if os(iOS)
            Button { showCameraPicker = true } label: {
                Label(String(localized: "Camera"), systemImage: "camera")
            }
#elseif os(macOS)
            Button { showImageFilePicker = true } label: {
                Label(String(localized: "Image File..."), systemImage: "photo.badge.plus")
            }
#endif
            Button { showImagePicker = true } label: {
                Label(String(localized: "Photo Library"), systemImage: "photo.on.rectangle")
            }
            Button { showDocumentPicker = true } label: {
                Label(String(localized: "Document"), systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
        }
        .accessibilityLabel(String(localized: "Add Attachment"))
    }

    func webSearchButton(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        Button { viewModel.send(.webSearchToggled) } label: {
            Image(systemName: loadedState.isWebSearchEnabled ? "globe.badge.chevron.backward" : "globe")
                .foregroundStyle(loadedState.isWebSearchEnabled ? Color.appAccent : .secondary)
        }
        .disabled(!canUseWebSearch(loadedState))
        .accessibilityLabel(
            loadedState.isWebSearchEnabled
            ? String(localized: "Disable Web Search")
            : String(localized: "Enable Web Search")
        )
    }

    @ViewBuilder
    func agentButton(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        if loadedState.selectedModel?.capabilities.contains(.functionCalling) == true {
            Button { viewModel.send(.agentToggled) } label: {
                Image(systemName: loadedState.isAgentEnabled ? "wand.and.stars" : "wand.and.stars.inverse")
                    .foregroundStyle(loadedState.isAgentEnabled ? Color.appAccent : .secondary)
            }
            .accessibilityLabel(
                loadedState.isAgentEnabled
                ? String(localized: "Disable Agent")
                : String(localized: "Enable Agent")
            )
        }
    }

    func actionButton(_ loadedState: EphemeralChatViewModel.LoadedState) -> some View {
        Button {
            viewModel.send(loadedState.isStreaming ? .stopStreamingTapped : .sendTapped)
        } label: {
            Image(systemName: loadedState.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(loadedState.isStreaming ? .red : Color.appAccent)
        }
        .disabled(!loadedState.isStreaming && !canSend(loadedState))
        .accessibilityLabel(loadedState.isStreaming ? String(localized: "Stop") : String(localized: "Send"))
    }

    func canSend(_ loadedState: EphemeralChatViewModel.LoadedState) -> Bool {
        let hasInput = !loadedState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return loadedState.selectedModel != nil && (hasInput || !loadedState.pendingAttachments.isEmpty)
    }

    func canUseWebSearch(_ loadedState: EphemeralChatViewModel.LoadedState) -> Bool {
        loadedState.isAgentEnabled &&
            loadedState.isWebSearchToolConfigured &&
            loadedState.selectedModel?.capabilities.contains(.functionCalling) == true
    }

    func addAttachment(data: Data, fileName: String, type: ChatMessage.AttachmentType) {
        viewModel.send(.attachmentAdded(data: data, fileName: fileName, type: type))
    }
}

#Preview {
    EphemeralChatView()
}
