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
                modelsList(loadedState.models)
            }
        }
    }

    func modelsList(_ models: [LLMModel]) -> some View {
        List(models) { model in
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

                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ModelsView()
}
