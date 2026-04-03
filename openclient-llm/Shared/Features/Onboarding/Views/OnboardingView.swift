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

            GeometryReader { proxy in
                ScrollView {
                    stepContent(loadedState)
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            bottomAction(loadedState)
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .animation(.smooth, value: loadedState.currentStep)
        .tint(Color.appAccent)
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
                    Image(systemName: "chevron.left").hidden()
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

            stepIndicator(currentStep: loadedState.currentStep)
        }
    }

    func stepIndicator(currentStep: OnboardingStep) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.appAccent : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    func stepContent(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        switch loadedState.currentStep {
        case .welcome:
            welcomeStep()
        case .serverConfiguration:
            serverConfigurationStep(loadedState)
        case .allSet:
            allSetStep(loadedState)
        }
    }

    func welcomeStep() -> some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.appAccent.opacity(0.08))
                    .frame(width: 160, height: 160)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                    .symbolEffect(.breathe)
            }

            VStack(spacing: 10) {
                Text(String(localized: "Your AI, Your Way"))
                    .font(.poppins(.bold, size: 34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)

                Text(String(localized: "OpenClient connects to your LiteLLM for privacy-first access to any AI."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 10) {
                featureRow(
                    icon: "server.rack",
                    tint: Color.appAccent,
                    title: String(localized: "Any Model"),
                    subtitle: String(localized: "GPT, Claude, Gemini, Llama and more via LiteLLM")
                )
                featureRow(
                    icon: "lock.shield.fill",
                    tint: .green,
                    title: String(localized: "Privacy First"),
                    subtitle: String(localized: "Your data stays on your own server — no telemetry")
                )
                featureRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    tint: .purple,
                    title: String(localized: "Open Source"),
                    subtitle: String(localized: "Fully open source on GitHub — inspect or contribute")
                )
            }
        }
    }

    func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.semiBold, size: 15, relativeTo: .subheadline))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.primary.opacity(0.04), in: .rect(cornerRadius: 14))
    }

    func serverConfigurationStep(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                    .symbolEffect(.pulse)
                    .frame(width: 80, height: 80)
                    #if os(macOS)
                    .background(Color.appAccent.opacity(0.12), in: .circle)
                    #else
                    .glassEffect(.regular.tint(Color.appAccent), in: .circle)
                    #endif

                VStack(spacing: 6) {
                    Text(String(localized: "Connect Your Server"))
                        .font(.poppins(.semiBold, size: 28, relativeTo: .title))
                        .multilineTextAlignment(.center)

                    Text(String(localized: "Enter your LiteLLM proxy URL, the gateway to any AI model."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Server URL"), systemImage: "link")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    TextField(
                        "http://localhost:4000",
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
                        String(localized: "sk-..."),
                        text: $apiKey
                    )
                } else {
                    SecureField(
                        String(localized: "sk-..."),
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
        VStack(spacing: 12) {
            Button {
                viewModel.send(.testConnectionTapped)
            } label: {
                HStack(spacing: 8) {
                    if loadedState.connectionStatus == .testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(
                        loadedState.connectionStatus == .testing
                            ? String(localized: "Testing...")
                            : String(localized: "Test Connection")
                    )
                }
                .frame(maxWidth: .infinity)
            }
            #if os(macOS)
            .buttonStyle(.bordered)
            .controlSize(.large)
            #else
            .buttonStyle(.glass)
            .controlSize(.large)
            #endif
            .disabled(loadedState.serverURL.isEmpty || loadedState.connectionStatus == .testing)

            switch loadedState.connectionStatus {
            case .idle, .testing:
                EmptyView()
            case .success:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "Connection successful — ready to continue"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .failure(let message):
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text(message)
                        .lineLimit(2)
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: loadedState.connectionStatus)
    }

    func allSetStep(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 170, height: 170)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce)
            }

            VStack(spacing: 10) {
                Text(String(localized: "You're all set!"))
                    .font(.poppins(.bold, size: 34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)

                Text(String(localized: "Your server is ready. Let's start a conversation."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if !loadedState.serverURL.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                    Text(loadedState.serverURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                #if os(macOS)
                .background(Color.appAccent.opacity(0.08), in: .capsule)
                #else
                .glassEffect(.regular, in: .capsule)
                #endif
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
            HStack(spacing: 8) {
                Text(String(localized: "Get Started"))
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }, action: {
            withAnimation(.smooth) { viewModel.send(.getStartedTapped) }
        })
    }

    func nextButton(_ loadedState: OnboardingViewModel.LoadedState) -> some View {
        prominentButton(isDisabled: loadedState.connectionStatus != .success, label: {
            HStack(spacing: 8) {
                Text(String(localized: "Continue"))
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }, action: {
            withAnimation(.smooth) { viewModel.send(.nextTapped) }
        })
    }

    func startChattingButton() -> some View {
        prominentButton(label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.headline)
                Text(String(localized: "Start Chatting"))
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
            }
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
