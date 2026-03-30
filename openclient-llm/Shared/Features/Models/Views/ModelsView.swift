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
        NavigationStack {
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
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ModelsView {
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
        List(loadedState.models) { model in
            Button {
                viewModel.send(.modelTapped(model))
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.id)
                                .font(.body)
                            if !model.ownedBy.isEmpty {
                                Text(model.ownedBy)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if model.id == loadedState.selectedModelId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Image(systemName: "cpu")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !model.capabilities.isEmpty {
                        capabilityTags(model.capabilities)
                    }
                }
            }
            .listRowBackground(
                model.id == loadedState.selectedModelId
                    ? Color.accentColor.opacity(0.08)
                    : nil
            )
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
