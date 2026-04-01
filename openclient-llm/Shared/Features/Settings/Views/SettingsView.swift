//
//  SettingsView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if os(iOS)
import StoreKit
#endif
import VoticeSDK

struct SettingsView: View {
    // MARK: - Properties

    @State private var viewModel = SettingsViewModel()
    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var isShowingVotice = false
    @State private var isShowingUserProfile = false
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
            .sheet(isPresented: $isShowingVotice) {
                Votice.feedbackView()
            }
            .sheet(isPresented: $isShowingUserProfile) {
                UserProfileView()
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
        VStack(spacing: 0) {
            Form {
                serverSection(loadedState)
                cloudSyncSection(loadedState)
                personalizationSection()
                chatSection(loadedState)
                feedbackSection()
                legalSection()
            }
#if os(iOS)
            .scrollDismissesKeyboard(.immediately)
#endif
        }
    }

    func serverSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            serverURLField()
            apiKeyField()
            connectionStatusView(loadedState.connectionStatus)
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
#if os(macOS)
            .buttonStyle(.bordered)
#endif
            .disabled(loadedState.serverURL.isEmpty || loadedState.connectionStatus == .testing)

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

    func feedbackSection() -> some View {
        Section {
            Button {
                requestAppReview()
            } label: {
                Label(String(localized: "Rate the App"), systemImage: "star")
            }

            Button {
                isShowingVotice = true
            } label: {
                Label(String(localized: "Suggest Features"), systemImage: "lightbulb")
            }
        } header: {
            Text(String(localized: "Feedback"))
        }
    }

    func cloudSyncSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { loadedState.isCloudSyncEnabled },
                set: { viewModel.send(.cloudSyncToggled($0)) }
            )) {
                Label(String(localized: "iCloud Sync"), systemImage: "icloud")
            }
            .disabled(!loadedState.isCloudAvailable)

            if !loadedState.isCloudAvailable {
                Label(
                    String(localized: "Sign in to iCloud to enable sync"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "Sync"))
        } footer: {
            Text(String(localized: "Sync conversations across your devices via iCloud."))
        }
    }

    func chatSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { loadedState.showTokenUsage },
                set: { viewModel.send(.showTokenUsageToggled($0)) }
            )) {
                Label(String(localized: "Show Token Usage"), systemImage: "number")
            }
        } header: {
            Text(String(localized: "Chat"))
        } footer: {
            Text(String(localized: "Show token count below each assistant response."))
        }
    }

    func personalizationSection() -> some View {
        Section {
            Button {
                isShowingUserProfile = true
            } label: {
                Label(String(localized: "Personal Context"), systemImage: "person.text.rectangle")
            }
        } header: {
            Text(String(localized: "Personalization"))
        } footer: {
            Text(String(localized: "Configure your name and personal context to personalise model responses."))
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

            Button {
                presentedWebURL = .authorGitHub
            } label: {
                HStack {
                    Label(String(localized: "Author"), systemImage: "person.circle")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(String(localized: "Version \(appVersion) (\(appBuild))"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
                Spacer()
            }
        } header: {
            Text(String(localized: "About"))
        }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    func requestAppReview() {
#if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        AppStore.requestReview(in: windowScene)
#else
        if let url = URL(string: "macappstore://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review") {
            NSWorkspace.shared.open(url)
        }
#endif
    }
}

// MARK: - WebDestination

extension SettingsView {
    enum WebDestination: Identifiable {
        case privacyPolicy
        case termsOfUse
        case authorGitHub

        // MARK: - Properties

        var id: String {
            switch self {
            case .privacyPolicy: "privacy"
            case .termsOfUse: "terms"
            case .authorGitHub: "author"
            }
        }

        var title: String {
            switch self {
            case .privacyPolicy: String(localized: "Privacy Policy")
            case .termsOfUse: String(localized: "Terms of Use")
            case .authorGitHub: "Arturo Carretero Calvo"
            }
        }

        var url: URL? {
            switch self {
            case .privacyPolicy:
                Constants.URLs.privacyPolicy
            case .termsOfUse:
                Constants.URLs.termsOfUse
            case .authorGitHub:
                Constants.URLs.authorGitHub
            }
        }
    }
}

#Preview {
    SettingsView()
}
