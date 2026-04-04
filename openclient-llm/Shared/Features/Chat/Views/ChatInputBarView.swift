//
//  ChatInputBarView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

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
    let onAudioRecorded: (Data, TimeInterval) -> Void

    @State private var audioRecorder = AudioRecorderManager()
    @Binding var showImageFilePicker: Bool

    // MARK: - View

    var body: some View {
        HStack(spacing: 8) {
            attachmentMenu

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Private

private extension ChatInputBarView {
    @ViewBuilder
    var attachmentMenu: some View {
        Menu {
#if os(iOS)
            Button {
                showCameraPicker = true
            } label: {
                Label(String(localized: "Camera"), systemImage: "camera")
            }
#endif
#if os(macOS)
            Button {
                showImageFilePicker = true
            } label: {
                Label(String(localized: "Image File..."), systemImage: "photo.badge.plus")
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
    var actionButton: some View {
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

    var stopStreamingButton: some View {
        Button { onStopStreaming() } label: {
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
        Button { inputText = ""; onSend() } label: {
            Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Color.appAccent)
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

    func startRecording() {
        audioRecorder.startRecording()
    }

    func stopRecording() {
        audioRecorder.stopRecording { data, duration in
            guard let data else { return }
            onAudioRecorded(data, duration)
        }
    }
}
