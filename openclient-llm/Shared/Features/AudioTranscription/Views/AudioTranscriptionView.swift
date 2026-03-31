//
//  AudioTranscriptionView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioTranscriptionView: View {
    // MARK: - Properties

    @State private var viewModel = AudioTranscriptionViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var showFilePicker: Bool = false

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
            .navigationTitle(String(localized: "Transcription"))
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension AudioTranscriptionView {
    func loadedView(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            if loadedState.availableModels.isEmpty {
                noModelsState
            } else {
                transcriptionsList(loadedState)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 0) {
                            errorBanner(loadedState.errorMessage)
                            configBar(loadedState)
                            audioBar(loadedState)
                        }
                    }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    var noModelsState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .frame(width: 80, height: 80)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(String(localized: "No Transcription Models Available"))
                    .font(.title2)
                    .fontWeight(.semibold)

                // swiftlint:disable line_length
                Text(String(localized: "Your server has no audio transcription models configured. Add a model like whisper-1 to your LiteLLM configuration."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                // swiftlint:enable line_length
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Transcriptions List

    func transcriptionsList(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        ScrollView {
            if loadedState.transcriptions.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(loadedState.transcriptions) { transcription in
                        transcriptionCard(transcription)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(String(localized: "Audio Transcription"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "Record or upload audio to transcribe"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    func transcriptionCard(_ transcription: Transcription) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcription.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Label(transcription.modelId, systemImage: "cpu")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if transcription.duration > 0 {
                    Label(
                        formattedDuration(transcription.duration),
                        systemImage: "clock"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(transcription.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .contextMenu {
            Button {
                copyToClipboard(transcription.text)
            } label: {
                Label(String(localized: "Copy"), systemImage: "doc.on.doc")
            }

            ShareLink(item: transcription.text) {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
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
            .background(Color.red.opacity(0.85))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Config Bar

    func configBar(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        HStack(spacing: 12) {
            modelPicker(loadedState)

            TextField(
                String(localized: "Language (optional)"),
                text: Binding(
                    get: { loadedState.language },
                    set: { viewModel.send(.languageChanged($0)) }
                )
            )
            .textFieldStyle(.plain)
            .font(.caption)
            .frame(maxWidth: 120)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func modelPicker(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        Menu {
            ForEach(loadedState.availableModels) { model in
                Button {
                    viewModel.send(.modelSelected(model.id))
                } label: {
                    HStack {
                        Text(model.id)
                        if model.id == loadedState.selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption)
                Text(loadedState.selectedModel.isEmpty
                     ? String(localized: "Select Model")
                     : loadedState.selectedModel)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .id(loadedState.selectedModel)
    }

    // MARK: - Audio Bar

    func audioBar(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        HStack(spacing: 12) {
            fileButton

            if loadedState.audioData != nil {
                audioPreview(loadedState)
            } else {
                recordButton(loadedState)
            }

            transcribeButton(loadedState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    var fileButton: some View {
        Button {
            showFilePicker = true
        } label: {
            Image(systemName: "doc.badge.plus")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Select Audio File"))
    }

    func recordButton(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        Button {
            if audioRecorder.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(audioRecorder.isRecording ? .red : Color.accentColor)

                if audioRecorder.isRecording {
                    Text(String(localized: "Recording..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "Tap to record"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            audioRecorder.isRecording
                ? String(localized: "Stop Recording")
                : String(localized: "Start Recording")
        )
    }

    func audioPreview(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(loadedState.audioFileName ?? "audio")
                    .font(.caption)
                    .lineLimit(1)
                if loadedState.audioDuration > 0 {
                    Text(formattedDuration(loadedState.audioDuration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                viewModel.send(.clearTapped)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func transcribeButton(_ loadedState: AudioTranscriptionViewModel.LoadedState) -> some View {
        if loadedState.isTranscribing {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 44, minHeight: 44)
        } else if loadedState.audioData != nil && !loadedState.selectedModel.isEmpty {
            Button {
                viewModel.send(.transcribeTapped)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Transcribe"))
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    func startRecording() {
        audioRecorder.startRecording()
    }

    func stopRecording() {
        audioRecorder.stopRecording { data, duration in
            if let data {
                viewModel.send(.audioRecorded(data, duration))
            }
        }
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
        viewModel.send(.audioFileSelected(data, url.lastPathComponent))
    }

    func formattedDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#Preview {
    AudioTranscriptionView()
}
