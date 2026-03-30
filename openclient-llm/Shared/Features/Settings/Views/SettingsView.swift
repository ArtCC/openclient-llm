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
    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var presentedWebURL: WebDestination?
    @FocusState private var focusedField: Field?

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
            .sheet(item: $presentedWebURL) { destination in
                if let url = destination.url {
                    WebContentView(title: destination.title, url: url)
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
            if case .loaded(let initialState) = viewModel.state {
                serverURL = initialState.serverURL
                apiKey = initialState.apiKey
            }
        }
    }
}

// MARK: - Private

private extension SettingsView {
    enum Field {
        case serverURL
        case apiKey
    }

    func loadedView(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Form {
            serverSection(loadedState)
            connectionSection(loadedState)
            saveSection(loadedState)
            legalSection()
        }
#if os(iOS)
        .scrollDismissesKeyboard(.immediately)
#endif
    }

    func serverSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            serverURLField()
            apiKeyField()
        } header: {
            Text(String(localized: "Server"))
        }
    }

    func serverURLField() -> some View {
        TextField(
            String(localized: "Server URL"),
            text: $serverURL
        )
        .focused($focusedField, equals: .serverURL)
        .textSelection(.enabled)
        .textContentType(.URL)
        .autocorrectionDisabled()
        #if os(iOS)
        .textInputAutocapitalization(.never)
        .keyboardType(.URL)
        #endif
        .onChange(of: serverURL) { _, newValue in
            viewModel.send(.serverURLChanged(newValue))
        }
    }

    func apiKeyField() -> some View {
        HStack {
            Group {
                if isAPIKeyVisible {
                    TextField(
                        String(localized: "API Key (Optional)"),
                        text: $apiKey
                    )
                    .focused($focusedField, equals: .apiKey)
                } else {
                    SecureField(
                        String(localized: "API Key (Optional)"),
                        text: $apiKey
                    )
                    .focused($focusedField, equals: .apiKey)
                }
            }
            .textSelection(.enabled)

            Button {
                isAPIKeyVisible.toggle()
            } label: {
                Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isAPIKeyVisible
                    ? String(localized: "Hide API Key")
                    : String(localized: "Show API Key")
            )
        }
        .onChange(of: apiKey) { _, newValue in
            viewModel.send(.apiKeyChanged(newValue))
        }
    }

    func connectionSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Button {
                focusedField = nil
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
                focusedField = nil
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

    func legalSection() -> some View {
        Section {
            Button {
                presentedWebURL = .privacyPolicy
            } label: {
                Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
            }

            Button {
                presentedWebURL = .termsOfUse
            } label: {
                Label(String(localized: "Terms of Use"), systemImage: "doc.text")
            }
        } header: {
            Text(String(localized: "About"))
        }
    }
}

// MARK: - WebDestination

extension SettingsView {
    enum WebDestination: Identifiable {
        case privacyPolicy
        case termsOfUse

        // MARK: - Properties

        var id: String {
            switch self {
            case .privacyPolicy: "privacy"
            case .termsOfUse: "terms"
            }
        }

        var title: String {
            switch self {
            case .privacyPolicy: String(localized: "Privacy Policy")
            case .termsOfUse: String(localized: "Terms of Use")
            }
        }

        var url: URL? {
            switch self {
            case .privacyPolicy:
                Constants.URLs.privacyPolicy
            case .termsOfUse:
                Constants.URLs.termsOfUse
            }
        }
    }
}

#Preview {
    SettingsView()
}
