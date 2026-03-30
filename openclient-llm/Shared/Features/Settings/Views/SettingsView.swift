//
//  SettingsView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @State private var viewModel = SettingsViewModel()

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
            .navigationTitle(String(localized: "Settings"))
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension SettingsView {
    func loadedView(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Form {
            serverSection(loadedState)
            connectionSection(loadedState)
            saveSection(loadedState)
        }
    }

    func serverSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            TextField(
                String(localized: "Server URL"),
                text: Binding(
                    get: { loadedState.serverURL },
                    set: { viewModel.send(.serverURLChanged($0)) }
                )
            )
            .textContentType(.URL)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            #endif

            SecureField(
                String(localized: "API Key (Optional)"),
                text: Binding(
                    get: { loadedState.apiKey },
                    set: { viewModel.send(.apiKeyChanged($0)) }
                )
            )
        } header: {
            Text(String(localized: "Server"))
        }
    }

    func connectionSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Button {
                viewModel.send(.testConnectionTapped)
            } label: {
                HStack(spacing: 8) {
                    if loadedState.connectionStatus == .testing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(
                        loadedState.connectionStatus == .testing
                            ? String(localized: "Testing...")
                            : String(localized: "Test Connection")
                    )
                }
            }
            .disabled(loadedState.serverURL.isEmpty || loadedState.connectionStatus == .testing)

            connectionStatusView(loadedState.connectionStatus)
        } header: {
            Text(String(localized: "Connection"))
        }
    }

    func saveSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Button {
                viewModel.send(.saveTapped)
            } label: {
                HStack {
                    Text(String(localized: "Save"))
                    Spacer()
                    if loadedState.isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func connectionStatusView(_ status: SettingsViewModel.ConnectionStatus) -> some View {
        switch status {
        case .idle, .testing:
            EmptyView()
        case .success:
            Label(String(localized: "Connection successful"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
}
