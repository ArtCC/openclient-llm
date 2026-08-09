//
//  ChatInputBarView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import TipKit

struct ChatInputBarView: View {
    // MARK: - Properties

    @Binding var inputText: String
    @Binding var showImagePicker: Bool
    @Binding var showDocumentPicker: Bool
    @Binding var showCameraPicker: Bool

    let loadedState: ChatViewModel.LoadedState
    let onInputChanged: (String) -> Void
    let onSend: () -> Void
    let onStopStreaming: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelRecording: () -> Void
    let onWebSearchToggled: () -> Void
    let onMCPButtonTapped: () -> Void

    @State private var isPulsing = false
    @Binding var showActions: Bool
    @Binding var showImageFilePicker: Bool

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if loadedState.isSearchingWeb {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.secondary)
                        Text(String(localized: "Searching the web..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let usage = loadedState.contextUsage {
                    ChatContextUsageView(usage: usage)
                        .popoverTip(
                            usage.percentage >= 50 && !loadedState.isStreaming
                                ? AppTips.contextUsage
                                : nil,
                            arrowEdge: .bottom
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, loadedState.isSearchingWeb ? 4 : 10)
                        .padding(.bottom, 4)
                }

                ZStack {
                    if loadedState.isRecording {
                        recordingBar
                            .transition(.asymmetric(
                                insertion: .push(from: .trailing).combined(with: .opacity),
                                removal: .push(from: .leading).combined(with: .opacity)
                            ))
                    } else if loadedState.isTranscribing {
                        transcribingBar
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
                    } else {
                        normalBar
                            .transition(.asymmetric(
                                insertion: .push(from: .leading).combined(with: .opacity),
                                removal: .push(from: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 25))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
        .animation(.spring(duration: 0.35), value: loadedState.isRecording)
        .animation(.spring(duration: 0.35), value: loadedState.isTranscribing)
        .animation(.easeInOut(duration: 0.2), value: loadedState.isSearchingWeb)
    }
}

// MARK: - Private

private extension ChatInputBarView {
    // MARK: Bar states

    var normalBar: some View {
        HStack(spacing: 5) {
            if loadedState.selectedModel?.mode != .imageGeneration {
                actionsToggleButton

                if showActions {
                    attachmentMenu
                        .transition(.scale.combined(with: .opacity))

                    webSearchButton
                        .transition(.scale.combined(with: .opacity))

                    mcpButton
                        .transition(.scale.combined(with: .opacity))
                }
            }

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
                onSend()
            }
            .onChange(of: inputText) { _, newValue in
                onInputChanged(newValue)
            }
            .onChange(of: loadedState.inputText) { _, newValue in
                if newValue != inputText {
                    inputText = newValue
                }
            }

            actionButton
        }
        .onAppear {
            if loadedState.inputText != inputText {
                inputText = loadedState.inputText
            }
        }
    }

    var recordingBar: some View {
        HStack(spacing: 12) {
            recordingIndicator

            Text(timerText)
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Spacer()

            Button { onCancelRecording() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Cancel Recording"))

            Button { onStopRecording() } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Stop Recording"))
        }
        .onAppear { startPulse() }
        .onDisappear { isPulsing = false }
    }

    var transcribingBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)

            Text(String(localized: "Transcribing..."))
                .foregroundStyle(.secondary)

            Spacer()

            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
        }
        .frame(minHeight: 44)
    }

    // MARK: Recording indicator

    var recordingIndicator: some View {
        ZStack {
            Circle()
                .fill(.red.opacity(0.25))
                .frame(width: 28, height: 28)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.8)

            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
        }
        .frame(width: 44, height: 44)
    }

    var timerText: String {
        let total = Int(loadedState.recordingDuration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Normal bar subviews

    @ViewBuilder
    var attachmentMenu: some View {
        Menu {
#if os(iOS)
            Button {
                AppTips.chatAttachments.invalidate(reason: .actionPerformed)
                showCameraPicker = true
            } label: {
                Label(String(localized: "Camera"), systemImage: "camera")
            }
#endif
#if os(macOS)
            Button {
                AppTips.chatAttachments.invalidate(reason: .actionPerformed)
                showImageFilePicker = true
            } label: {
                Label(String(localized: "Image File..."), systemImage: "photo.badge.plus")
            }
#endif
            Button {
                AppTips.chatAttachments.invalidate(reason: .actionPerformed)
                showDocumentPicker = true
            } label: {
                Label(String(localized: "Document"), systemImage: "doc")
            }

            Button {
                AppTips.chatAttachments.invalidate(reason: .actionPerformed)
                showImagePicker = true
            } label: {
                Label(String(localized: "Photo Library"), systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popoverTip(canShowInputTips ? AppTips.chatAttachments : nil, arrowEdge: .bottom)
    }

    var webSearchButton: some View {
        let modelSupportsWebSearch = loadedState.selectedModel.map {
            $0.capabilities.contains(.functionCalling)
        } ?? false

        return Button {
            AppTips.webSearch.invalidate(reason: .actionPerformed)
            onWebSearchToggled()
        } label: {
            Image(systemName: loadedState.isWebSearchEnabled ? "globe.badge.chevron.backward" : "globe")
                .font(.title2)
                .foregroundStyle(
                    webSearchColor(
                        enabled: loadedState.isWebSearchEnabled,
                        supported: modelSupportsWebSearch,
                        configured: loadedState.isWebSearchToolConfigured
                    )
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popoverTip(canShowWebSearchTip ? AppTips.webSearch : nil, arrowEdge: .bottom)
        .accessibilityLabel(
            loadedState.isWebSearchEnabled
            ? String(localized: "Disable Web Search")
            : String(localized: "Enable Web Search")
        )
        .animation(.easeInOut(duration: 0.2), value: loadedState.isWebSearchEnabled)
    }

    var actionsToggleButton: some View {
        let hasActive = loadedState.isWebSearchEnabled || !loadedState.enabledMCPToolIds.isEmpty
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showActions.toggle()
            }
        } label: {
            ZStack {
                Image(systemName: showActions ? "xmark.circle" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                if hasActive && !showActions {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -10)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showActions
            ? String(localized: "Hide Actions")
            : String(localized: "Show Actions"))
    }

    var mcpButton: some View {
        let modelSupportsTools = loadedState.selectedModel.map {
            $0.capabilities.contains(.functionCalling)
        } ?? false

        return Button {
            AppTips.mcpServers.invalidate(reason: .actionPerformed)
            onMCPButtonTapped()
        } label: {
            Image(systemName: mcpIcon(modelSupportsTools))
                .font(.title2)
                .foregroundStyle(
                    mcpColor(
                        supported: loadedState.isMCPSupported && modelSupportsTools,
                        hasEnabled: !loadedState.enabledMCPToolIds.isEmpty
                    )
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popoverTip(canShowMCPTip ? AppTips.mcpServers : nil, arrowEdge: .bottom)
        .accessibilityLabel(
            loadedState.isMCPSupported && modelSupportsTools
            ? String(localized: "MCP Servers")
            : String(localized: "MCP Servers Unavailable")
        )
        .animation(.easeInOut(duration: 0.2), value: loadedState.enabledMCPToolIds)
    }

    func mcpIcon(_ modelSupportsTools: Bool) -> String {
        "server.rack"
    }

    func mcpColor(supported: Bool, hasEnabled: Bool) -> Color {
        guard supported else { return .red }
        return hasEnabled ? Color.appAccent : .secondary
    }

    @ViewBuilder
    var actionButton: some View {
        let hasText = !loadedState.inputText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let hasModel = loadedState.selectedModel != nil
        let hasAttachments = !loadedState.pendingAttachments.isEmpty
        let hasTranscriptionModel = loadedState.transcriptionModelId != nil

        if loadedState.isPreparingAttachment {
            ProgressView()
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(String(localized: "Preparing image"))
        } else if loadedState.isStreaming {
            if (hasText || hasAttachments) && hasModel {
                sendButton
            } else {
                stopStreamingButton
            }
        } else {
            if (hasText || hasAttachments) && hasModel {
                sendButton
            } else if hasModel && hasTranscriptionModel {
                micButton
            }
        }
    }

    var stopStreamingButton: some View {
        Button { onStopStreaming() } label: {
            Image(systemName: "stop.circle.fill").font(.title2).foregroundStyle(.red)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Stop"))
        .transition(.scale.combined(with: .opacity))
    }

    var sendButton: some View {
        Button { inputText = ""; onSend() } label: {
            Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(Color.appAccent)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Send"))
        .transition(.scale.combined(with: .opacity))
    }

    var micButton: some View {
        Button { onStartRecording() } label: {
            Image(systemName: "mic.circle.fill").font(.title2).foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Record Audio"))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Actions

    func startPulse() {
        isPulsing = false
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }

    func webSearchColor(enabled: Bool, supported: Bool, configured: Bool) -> Color {
        guard configured && supported else { return .red }
        return enabled ? Color.appAccent : .secondary
    }

    var canShowInputTips: Bool {
        loadedState.selectedModel != nil
            && !loadedState.isStreaming
            && !loadedState.isRecording
            && !loadedState.isTranscribing
            && !loadedState.isSearchingWeb
    }

    var canShowWebSearchTip: Bool {
        canShowInputTips
            && loadedState.isWebSearchToolConfigured
            && loadedState.selectedModel?.capabilities.contains(.functionCalling) == true
    }

    var canShowMCPTip: Bool {
        canShowInputTips
            && loadedState.isMCPSupported
            && loadedState.selectedModel?.capabilities.contains(.functionCalling) == true
    }
}
