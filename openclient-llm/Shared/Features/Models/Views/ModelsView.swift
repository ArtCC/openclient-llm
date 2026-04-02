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
        let localModels = loadedState.models.filter { $0.provider == .local }
        let cloudModels = loadedState.models.filter { $0.provider == .cloud }

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
        }
    }

    func modelRow(_ model: LLMModel, loadedState: ModelsViewModel.LoadedState) -> some View {
        let isSelected = model.id == loadedState.selectedModelId

        return Button {
            viewModel.send(.modelTapped(model))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
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
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: model.provider.icon)
                            .foregroundStyle(.secondary)
                    }
                }

                if !model.capabilities.isEmpty {
                    capabilityTags(model.capabilities)
                }
            }
            .padding(.vertical, 4)
        }
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
}

#Preview {
    ModelsView()
}
