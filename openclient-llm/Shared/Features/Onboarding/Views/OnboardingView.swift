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
        .tint(.accentColor)
    }

    func topBar(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        ZStack {
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
                    #if os(macOS)
                    .buttonStyle(.bordered)
                    #else
                    .buttonStyle(.glass)
                    #endif
                } else {
                    Image(systemName: "chevron.left")
                        .hidden()
                }

                Spacer()

                Button {
                    viewModel.send(.skipTapped)
                } label: {
                    HStack(spacing: 4) {
                        Text(String(localized: "Skip"))
                        Image(systemName: "forward.fill")
                            .font(.caption2)
                    }
                }
                #if os(macOS)
                .buttonStyle(.bordered)
                #else
                .buttonStyle(.glass)
                #endif
            }

            HStack {
                Spacer()

                stepIndicator(currentStep: loadedState.currentStep)

                Spacer()
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
        }        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)    }

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
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.breathe)
                .padding(28)
                #if os(macOS)
                .background(Color.accentColor.opacity(0.12), in: .circle)
                #else
                .glassEffect(.regular, in: .circle)
                #endif

            VStack(spacing: 12) {
                Text(String(localized: "Welcome to OpenClient"))
                    .font(.poppins(.semiBold, size: 28, relativeTo: .title))
                    .multilineTextAlignment(.center)

                // swiftlint:disable:next line_length
                Text(String(localized: "Your gateway to any LLM through a unified interface. Connect to your LiteLLM server and start chatting."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    func serverConfigurationStep(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 20) {
            Text(String(localized: "Server Configuration"))
                .font(.poppins(.semiBold, size: 28, relativeTo: .title))

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
#if os(macOS)
            .buttonStyle(.bordered)
#endif
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
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
                .padding(28)
                #if os(macOS)
                .background(Color.green.opacity(0.12), in: .circle)
                #else
                .glassEffect(.regular, in: .circle)
                #endif

            VStack(spacing: 12) {
                Text(String(localized: "All Set!"))
                    .font(.poppins(.bold, size: 34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)

                // swiftlint:disable:next line_length
                Text(String(localized: "Your server is configured and ready to go. Start chatting with your AI models."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    func bottomAction(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        switch loadedState.currentStep {
        case .welcome:
            getStartedButton()
        case .serverConfiguration:
            nextButton(loadedState)
        case .allSet:
            startChattingButton()
        }
    }
}

// MARK: - Private

private extension OnboardingView {
    func prominentButton<Label: View>(
        isDisabled: Bool = false,
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action, label: label)
            #if os(macOS)
            .buttonStyle(.borderedProminent)
            #else
            .buttonStyle(.glassProminent)
            #endif
            .controlSize(.large)
            .disabled(isDisabled)
    }

    func getStartedButton() -> some View {
        prominentButton(label: {
            Text(String(localized: "Get Started"))
                .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }, action: {
            withAnimation(.smooth) { viewModel.send(.getStartedTapped) }
        })
    }

    func nextButton(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        prominentButton(isDisabled: loadedState.connectionStatus != .success, label: {
            Text(String(localized: "Next"))
                .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }, action: {
            withAnimation(.smooth) { viewModel.send(.nextTapped) }
        })
    }

    func startChattingButton() -> some View {
        prominentButton(label: {
            Text(String(localized: "Start Chatting"))
                .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }, action: {
            withAnimation(.smooth) { viewModel.send(.startChattingTapped) }
        })
    }
}

#Preview {
    OnboardingView {}
}
