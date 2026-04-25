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
import SwiftUI
#endif
import VoticeSDK

struct SettingsView: View {
    // MARK: - Properties

    @State var viewModel = SettingsViewModel()
    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var isShowingVotice = false
    @State private var isShowingUserProfile = false
    @State private var isShowingMemory = false
    @State private var isShowingHelp = false
    @State private var isShowingTipJar = false
    @State private var showResetAlert = false
    @State private var presentedWebURL: WebDestination?
    @FocusState private var focusedField: Field?
    @Environment(\.scenePhase) private var scenePhase
    private let liteLLMHintText = String(localized: "Optimised for LiteLLM. Any OpenAI-compatible server also works.")

    // MARK: - View

    var body: some View {
#if os(iOS)
        NavigationStack {
            settingsContent
        }
#else
        settingsContent
#endif
    }
}

// MARK: - Private

private extension SettingsView {
    var settingsContent: some View {
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
        .sheet(isPresented: $isShowingMemory) {
            MemoryView()
#if os(macOS)
                .frame(width: 500, height: 460)
#endif
        }
        .sheet(isPresented: $isShowingHelp) {
            HelpView()
#if os(macOS)
                .frame(width: 500, height: 460)
#endif
        }
        .sheet(isPresented: $isShowingTipJar) {
            TipJarView()
#if os(macOS)
                .frame(width: 500, height: 460)
#endif
        }
        .alert(
            String(localized: "iCloud Sync Conflict"),
            isPresented: cloudSyncConflictBinding,
            actions: {
                Button(String(localized: "Use Local Data")) {
                    viewModel.send(.cloudSyncConflictResolved(keepLocal: true))
                }
                Button(String(localized: "Use iCloud Data")) {
                    viewModel.send(.cloudSyncConflictResolved(keepLocal: false))
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    viewModel.send(.cloudSyncConflictCancelled)
                }
                .buttonStyle(.plain)
            },
            message: {
                Text(String(
                    localized: "Your local personal context differs from iCloud. Which version would you like to keep?"
                ))
            }
        )
        .alert(
            String(localized: "Reset App Data"),
            isPresented: $showResetAlert
        ) {
            Button(String(localized: "Reset"), role: .destructive) {
                viewModel.send(.resetConfirmed)
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "All local settings and credentials will be deleted. iCloud data will not be affected."
            ))
        }
        .task {
            viewModel.send(.viewAppeared)
            if case .loaded(let initialState) = viewModel.state {
                serverURL = initialState.serverURL
                apiKey = initialState.apiKey
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.send(.notificationStatusRefresh)
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .loaded(let loadedState) = newState {
                serverURL = loadedState.serverURL
                apiKey = loadedState.apiKey
            }
        }
    }

    enum Field {
        case serverURL
        case apiKey
    }

    var cloudSyncConflictBinding: Binding<Bool> {
        Binding(
            get: {
                guard case .loaded(let loadedState) = viewModel.state else { return false }
                return loadedState.showCloudSyncConflictAlert
            },
            set: { newValue in
                if !newValue {
                    viewModel.send(.cloudSyncConflictCancelled)
                }
            }
        )
    }

    func loadedView(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            Form {
                serverSection(loadedState)
                cloudSyncSection(loadedState)
                personalizationSection()
                chatSection(loadedState)
#if os(iOS)
                privacySection(loadedState)
#endif
                notificationsSection(loadedState)
                webSearchSection(loadedState)
                tipJarSection(isPresented: $isShowingTipJar)
                feedbackSection(isShowingVotice: $isShowingVotice)
                helpSection(isPresented: $isShowingHelp)
                legalSection()
                dangerSection()
            }
#if os(iOS)
            .scrollDismissesKeyboard(.immediately)
#elseif os(macOS)
            .formStyle(.grouped)
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
            .disabled(loadedState.serverURL.isEmpty || loadedState.connectionStatus == .testing)
            .buttonStyle(.plain)

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
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Server"))
        } footer: {
            if loadedState.showLiteLLMHint {
                Label(liteLLMHintText, systemImage: "info.circle").foregroundStyle(.secondary)
            }
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

    func notificationsSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            switch loadedState.notificationPermissionStatus {
            case .authorized:
                Label(String(localized: "Notifications enabled"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                Label(String(localized: "Notifications disabled"), systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
#if os(iOS)
                Button {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label(String(localized: "Open Settings"), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
#endif
            case .notDetermined:
                Label(String(localized: "Notifications not authorized"), systemImage: "bell.badge.slash")
                    .foregroundStyle(.secondary)
                Button {
                    viewModel.send(.requestNotificationPermissionTapped)
                } label: {
                    Label(String(localized: "Enable Notifications"), systemImage: "bell")
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "Notifications"))
        } footer: {
            Text(String(localized: "Sent when a response finishes while the app is in the background."))
        }
    }

    func personalizationSection() -> some View {
        Section {
            Button {
                isShowingUserProfile = true
            } label: {
                Label(String(localized: "Personal Context"), systemImage: "person.text.rectangle")
            }
            .buttonStyle(.plain)

            Button {
                isShowingMemory = true
            } label: {
                Label(String(localized: "Memory"), systemImage: "brain.head.profile")
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Personalization"))
        } footer: {
            Text(String(localized: "Configure your personal context and memory items to personalise model responses."))
        }
    }

    func legalSection() -> some View {
        Section {
            Button {
                presentedWebURL = .privacyPolicy
            } label: {
                Label(String(localized: "Privacy Policy"), systemImage: "hand.raised")
            }
            .buttonStyle(.plain)

            Button {
                presentedWebURL = .termsOfUse
            } label: {
                Label(String(localized: "Terms of Use"), systemImage: "doc.text")
            }
            .buttonStyle(.plain)

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
            .buttonStyle(.plain)

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

    func dangerSection() -> some View {
        Section {
            Button {
                showResetAlert = true
            } label: {
                Label(String(localized: "Reset App Data"), systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "App Data"))
        } footer: {
            Text(String(localized: "Deletes all local settings and credentials. iCloud data will not be affected."))
        }
    }
}

#Preview {
    SettingsView()
}
