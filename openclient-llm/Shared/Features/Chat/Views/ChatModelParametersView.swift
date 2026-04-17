//
//  ChatModelParametersView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatModelParametersView: View {
    // MARK: - Properties

    var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    @State private var temperatureEnabled: Bool = false
    @State private var temperature: Double = 0.7
    @State private var maxTokensEnabled: Bool = false
    @State private var maxTokens: Double = 4096
    @State private var topPEnabled: Bool = false
    @State private var topP: Double = 1.0

    // MARK: - View

    var body: some View {
        Group {
            #if os(macOS)
            macOSBody
            #else
            NavigationStack {
                form
                    .navigationTitle(String(localized: "Model Parameters"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done")) {
                                applyParameters()
                                isPresented = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Reset")) {
                                resetParameters()
                            }
                        }
                    }
            }
            #endif
        }
        #if os(macOS)
        .frame(width: 500, height: 460)
        #endif
        .task {
            loadCurrentParameters()
        }
    }
}

// MARK: - Private

private extension ChatModelParametersView {
    #if os(macOS)
    var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "Reset")) {
                    resetParameters()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Text(String(localized: "Model Parameters"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "Done")) {
                    applyParameters()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            form
        }
    }
    #endif

    var form: some View {
        Form {
            if let estimatedCost, estimatedCost > 0 {
                costSection(estimatedCost)
            }

            Section {
                Toggle(isOn: $temperatureEnabled) {
                    Label(String(localized: "Temperature"), systemImage: "thermometer.medium")
                }

                if temperatureEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $temperature, in: 0...2, step: 0.1) {
                            Text(String(localized: "Temperature"))
                        }
                        Text(String(localized: "\(temperature, specifier: "%.1f") — \(temperatureDescription)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(String(localized: "Controls randomness. Higher values make output more creative."))
            }

            Section {
                Toggle(isOn: $maxTokensEnabled) {
                    Label(String(localized: "Max Tokens"), systemImage: "textformat.123")
                }

                if maxTokensEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $maxTokens, in: 256...32768, step: 256) {
                            Text(String(localized: "Max Tokens"))
                        }
                        Text(String(localized: "\(Int(maxTokens)) tokens"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(String(localized: "Maximum number of tokens in the response."))
            }

            Section {
                Toggle(isOn: $topPEnabled) {
                    Label(String(localized: "Top P"), systemImage: "chart.bar")
                }

                if topPEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $topP, in: 0...1, step: 0.05) {
                            Text(String(localized: "Top P"))
                        }
                        Text(String(localized: "\(topP, specifier: "%.2f")"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(String(localized: "Nucleus sampling. Lower values make output more focused."))
            }
        }
#if os(macOS)
        .formStyle(.grouped)
#endif
    }

    var temperatureDescription: String {
        switch temperature {
        case 0...0.3: String(localized: "Focused")
        case 0.3...0.7: String(localized: "Balanced")
        case 0.7...1.2: String(localized: "Creative")
        default: String(localized: "Very creative")
        }
    }

    var estimatedCost: Double? {
        guard case .loaded(let loadedState) = viewModel.state,
              let model = loadedState.selectedModel,
              let inputRate = model.inputCostPerToken,
              let outputRate = model.outputCostPerToken,
              inputRate > 0 || outputRate > 0 else { return nil }

        let total = loadedState.messages.compactMap(\.tokenUsage).reduce(0.0) { acc, usage in
            acc + Double(usage.promptTokens) * inputRate + Double(usage.completionTokens) * outputRate
        }
        return total > 0 ? total : nil
    }

    func costSection(_ cost: Double) -> some View {
        Section {
            LabeledContent(String(localized: "Estimated cost")) {
                Text("~$\(cost, specifier: "%.4f")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } footer: {
            Text(String(localized: "Approximate cost of this conversation based on token usage and model pricing."))
        }
    }

    func loadCurrentParameters() {
        guard case .loaded(let loadedState) = viewModel.state else { return }
        let params = loadedState.modelParameters
        if let temp = params.temperature {
            temperatureEnabled = true
            temperature = temp
        }
        if let tokens = params.maxTokens {
            maxTokensEnabled = true
            maxTokens = Double(tokens)
        }
        if let top = params.topP {
            topPEnabled = true
            topP = top
        }
    }

    func applyParameters() {
        let parameters = ModelParameters(
            temperature: temperatureEnabled ? temperature : nil,
            maxTokens: maxTokensEnabled ? Int(maxTokens) : nil,
            topP: topPEnabled ? topP : nil
        )
        viewModel.send(.modelParametersChanged(parameters))
    }

    func resetParameters() {
        temperatureEnabled = false
        temperature = 0.7
        maxTokensEnabled = false
        maxTokens = 4096
        topPEnabled = false
        topP = 1.0
    }
}

#Preview {
    ChatModelParametersView(
        viewModel: ChatViewModel(),
        isPresented: .constant(true)
    )
}
