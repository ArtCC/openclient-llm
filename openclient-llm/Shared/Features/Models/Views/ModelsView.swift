//
//  ModelsView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ModelsView: View {
    // MARK: - Properties

    @State private var viewModel = ModelsViewModel()
    @State private var ttsCustomVoiceTexts: [String: String] = [:]
    @State private var ttsCustomModeActive: Set<String> = []

    // MARK: - View

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Private

private extension ModelsView {
    var content: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let loadedState):
                loadedView(loadedState)
            }
        }
        .navigationTitle(String(localized: "Models"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.send(.refreshTapped)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "Refresh"))
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }

    func loadedView(_ loadedState: ModelsViewModel.LoadedState) -> some View {
        Group {
            if let errorMessage = loadedState.errorMessage, loadedState.models.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Unable to Load Models"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(String(localized: "Retry")) {
                        viewModel.send(.refreshTapped)
                    }
                }
            } else {
                modelsList(loadedState)
            }
        }
    }

    func modelsList(_ loadedState: ModelsViewModel.LoadedState) -> some View {
        let chatModels = loadedState.models.filter {
            $0.mode != .audioSpeech && $0.mode != .audioTranscription
        }
        let ttsModels = loadedState.models.filter { $0.mode == .audioSpeech }
        let sttModels = loadedState.models.filter { $0.mode == .audioTranscription }
        let localModels = chatModels.filter { $0.provider == .local }
        let cloudModels = chatModels.filter { $0.provider == .cloud }

        return List {
            if !localModels.isEmpty {
                Section(String(localized: "Local")) {
                    ForEach(localModels) { model in
                        modelRow(model, loadedState: loadedState)
                    }
                }
            }
            if !cloudModels.isEmpty {
                Section(String(localized: "Cloud")) {
                    ForEach(cloudModels) { model in
                        modelRow(model, loadedState: loadedState)
                    }
                }
            }
            if !ttsModels.isEmpty {
                Section(String(localized: "Text to Speech")) {
                    ForEach(ttsModels) { model in
                        ttsModelRow(model, loadedState: loadedState)
                    }
                }
            }
            if !sttModels.isEmpty {
                Section(String(localized: "Speech to Text")) {
                    ForEach(sttModels) { model in
                        sttModelRow(model, loadedState: loadedState)
                    }
                }
            }
        }
        #if os(iOS)
        .refreshable {
            await viewModel.refreshAsync()
        }
        #endif
    }

    func modelRow(_ model: LLMModel, loadedState: ModelsViewModel.LoadedState) -> some View {
        let isSelected = model.id == loadedState.selectedModelId

        return Button {
            viewModel.send(.modelTapped(model))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    providerLogo(model)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.id)
                            .font(.body)
                        if !model.providerName.isEmpty {
                            Text(model.providerName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.appAccent)
                    }
                }

                if !model.capabilities.isEmpty {
                    capabilityTags(model.capabilities)
                }
            }
            .padding(.vertical, 4)
        }
    }

    func providerLogo(_ model: LLMModel) -> some View {
        Group {
            if let imageName = model.logoImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: model.provider.genericLogoSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func capabilityTags(_ capabilities: [LLMModel.Capability]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(capabilities, id: \.self) { capability in
                HStack(spacing: 4) {
                    Image(systemName: capability.icon)
                        .font(.caption2)
                    Text(capability.label)
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(capability.color)
                .background(capability.color.opacity(0.12), in: .capsule)
            }
        }
    }

    func ttsModelRow(_ model: LLMModel, loadedState: ModelsViewModel.LoadedState) -> some View {
        let isSelected = model.id == loadedState.selectedTTSModelId

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.send(.ttsModelTapped(model))
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        providerLogo(model)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.id)
                                .font(.body)
                            if !model.providerName.isEmpty {
                                Text(model.providerName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    if isSelected {
                        voicePicker(model: model, loadedState: loadedState)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    func sttModelRow(_ model: LLMModel, loadedState: ModelsViewModel.LoadedState) -> some View {
        let isSelected = model.id == loadedState.selectedSTTModelId

        return Button {
            viewModel.send(.sttModelTapped(model))
        } label: {
            HStack(spacing: 12) {
                providerLogo(model)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.id)
                        .font(.body)
                    if !model.providerName.isEmpty {
                        Text(model.providerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "waveform.badge.mic")
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.vertical, 4)
        }
    }

    func voicePicker(model: LLMModel, loadedState: ModelsViewModel.LoadedState) -> some View {
        let voicePresets = TTSVoice.presets.map(\.rawValue)
        let currentVoice = loadedState.selectedTTSVoices[model.id] ?? TTSVoice.alloy.rawValue
        let isPresetVoice = voicePresets.contains(currentVoice)
        let showCustomInput = ttsCustomModeActive.contains(model.id) || !isPresetVoice

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "Voice"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                voiceMenu(
                    model: model,
                    voicePresets: voicePresets,
                    currentVoice: currentVoice,
                    isPresetVoice: isPresetVoice
                )
            }

            if showCustomInput {
                voiceCustomField(model: model, currentVoice: currentVoice, isPresetVoice: isPresetVoice)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.leading, 44)
    }

    func voiceMenu(
        model: LLMModel,
        voicePresets: [String],
        currentVoice: String,
        isPresetVoice: Bool
    ) -> some View {
        Menu {
            ForEach(voicePresets, id: \.self) { preset in
                Button {
                    viewModel.send(.voiceSelected(preset, forModelId: model.id))
                    ttsCustomVoiceTexts.removeValue(forKey: model.id)
                    ttsCustomModeActive.remove(model.id)
                } label: {
                    if currentVoice == preset {
                        Label(preset.capitalized, systemImage: "checkmark")
                    } else {
                        Text(preset.capitalized)
                    }
                }
            }
            Divider()
            Button(String(localized: "Custom…")) {
                ttsCustomModeActive.insert(model.id)
                if !isPresetVoice {
                    ttsCustomVoiceTexts[model.id] = currentVoice
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(isPresetVoice && !ttsCustomModeActive.contains(model.id)
                     ? currentVoice.capitalized
                     : String(localized: "Custom…"))
                    .font(.subheadline)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.appAccent)
        }
    }

    func voiceCustomField(model: LLMModel, currentVoice: String, isPresetVoice: Bool) -> some View {
        TextField(
            String(localized: "Voice ID"),
            text: Binding(
                get: { ttsCustomVoiceTexts[model.id] ?? (isPresetVoice ? "" : currentVoice) },
                set: { ttsCustomVoiceTexts[model.id] = $0 }
            )
        )
        .textFieldStyle(.roundedBorder)
        .font(.subheadline)
        .onSubmit {
            let text = ttsCustomVoiceTexts[model.id] ?? ""
            guard !text.isEmpty else { return }
            viewModel.send(.voiceSelected(text, forModelId: model.id))
            ttsCustomVoiceTexts.removeValue(forKey: model.id)
            ttsCustomModeActive.remove(model.id)
        }
    }
}

#Preview {
    ModelsView()
}
