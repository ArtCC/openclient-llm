//
//  OnboardingView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct OnboardingView: View {
    // MARK: - Properties

    @State private var viewModel = OnboardingViewModel()
    @State private var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false

    let onComplete: () -> Void

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let loadedState):
                loadedView(loadedState)
            }
        }
        .task {
            viewModel.onComplete = onComplete
            viewModel.send(.viewAppeared)
            if case .loaded(let initialState) = viewModel.state {
                serverURL = initialState.serverURL
                apiKey = initialState.apiKey
            }
        }
    }
}

// MARK: - Private

private extension OnboardingView {
    func loadedView(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            topBar(loadedState)

            Spacer()

            stepContent(loadedState)
                .frame(maxWidth: 500)

            Spacer()

            bottomAction(loadedState)
                .frame(maxWidth: 500)
        }
        .padding()
        .animation(.smooth, value: loadedState.currentStep)
    }

    func topBar(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        HStack {
            if loadedState.currentStep != .welcome {
                Button {
                    withAnimation(.smooth) {
                        viewModel.send(.backTapped)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "Back"))
            } else {
                Image(systemName: "chevron.left")
                    .hidden()
            }

            Spacer()

            stepIndicator(currentStep: loadedState.currentStep)

            Spacer()

            Button(String(localized: "Skip")) {
                viewModel.send(.skipTapped)
            }
        }
    }

    func stepIndicator(currentStep: OnboardingStep) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    @ViewBuilder
    func stepContent(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        switch loadedState.currentStep {
        case .welcome:
            welcomeStep()
        case .serverConfiguration:
            serverConfigurationStep(loadedState)
        case .allSet:
            allSetStep()
        }
    }

    func welcomeStep() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)

            Text(String(localized: "Welcome to OpenClient"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // swiftlint:disable:next line_length
            Text(String(localized: "Your gateway to any LLM through a unified interface. Connect to your LiteLLM server and start chatting."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    func serverConfigurationStep(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 20) {
            Text(String(localized: "Server Configuration"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "Enter your LiteLLM server details to connect."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField(
                    String(localized: "Server URL"),
                    text: $serverURL
                )
                .textFieldStyle(.roundedBorder)
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

                apiKeyField
            }

            connectionSection(loadedState)
        }
    }

    var apiKeyField: some View {
        HStack {
            Group {
                if isAPIKeyVisible {
                    TextField(
                        String(localized: "API Key (Optional)"),
                        text: $apiKey
                    )
                } else {
                    SecureField(
                        String(localized: "API Key (Optional)"),
                        text: $apiKey
                    )
                }
            }
            .textFieldStyle(.roundedBorder)
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

    func connectionSection(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 8) {
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

            switch loadedState.connectionStatus {
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

    func allSetStep() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)

            Text(String(localized: "All Set!"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(String(localized: "Your server is configured and ready to go. Start chatting with your AI models."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    func bottomAction(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        switch loadedState.currentStep {
        case .welcome:
            Button {
                withAnimation(.smooth) {
                    viewModel.send(.getStartedTapped)
                }
            } label: {
                Text(String(localized: "Get Started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .serverConfiguration:
            Button {
                withAnimation(.smooth) {
                    viewModel.send(.nextTapped)
                }
            } label: {
                Text(String(localized: "Next"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(loadedState.connectionStatus != .success)

        case .allSet:
            Button {
                withAnimation(.smooth) {
                    viewModel.send(.startChattingTapped)
                }
            } label: {
                Text(String(localized: "Start Chatting"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

#Preview {
    OnboardingView {}
}
