//
//  ModelDetailView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 17/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ModelDetailView: View {
    // MARK: - Properties

    let model: LLMModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        Group {
            #if os(macOS)
            macOSBody
            #else
            NavigationStack {
                form
                    .navigationTitle(String(localized: "Model Info"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done")) {
                                dismiss()
                            }
                        }
                    }
            }
            #endif
        }
        #if os(macOS)
        .frame(width: 480, height: 420)
        #endif
    }
}

// MARK: - Private

private extension ModelDetailView {
    #if os(macOS)
    var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Text(String(localized: "Model Info"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "Done")) {
                    dismiss()
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
            headerSection

            if model.maxInputTokens != nil || model.maxOutputTokens != nil {
                contextWindowSection
            }

            if hasPricing {
                pricingSection
            }

            providerModeSection

            if !model.capabilities.isEmpty {
                capabilitiesSection
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                providerLogo

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.id)
                        .font(.body)
                        .fontWeight(.medium)
                    if !model.providerName.isEmpty {
                        Text(model.providerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    var contextWindowSection: some View {
        Section(String(localized: "Context Window")) {
            if let maxInput = model.maxInputTokens {
                LabeledContent(String(localized: "Input tokens")) {
                    Text(maxInput.formatted())
                        .foregroundStyle(.secondary)
                }
            }
            if let maxOutput = model.maxOutputTokens {
                LabeledContent(String(localized: "Output tokens")) {
                    Text(maxOutput.formatted())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var pricingSection: some View {
        Section(String(localized: "Pricing")) {
            if let inputCost = model.inputCostPerToken, inputCost > 0 {
                LabeledContent(String(localized: "Input")) {
                    Text(String(localized: "$\(inputCost * 1_000, specifier: "%.4f") / 1K tokens"))
                        .foregroundStyle(.secondary)
                }
            }
            if let outputCost = model.outputCostPerToken, outputCost > 0 {
                LabeledContent(String(localized: "Output")) {
                    Text(String(localized: "$\(outputCost * 1_000, specifier: "%.4f") / 1K tokens"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var providerModeSection: some View {
        Section(String(localized: "Details")) {
            if !model.providerName.isEmpty {
                LabeledContent(String(localized: "Provider")) {
                    HStack(spacing: 6) {
                        Image(systemName: model.provider.icon)
                            .font(.caption)
                        Text(model.providerName)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            LabeledContent(String(localized: "Type")) {
                Text(model.mode.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var capabilitiesSection: some View {
        Section(String(localized: "Capabilities")) {
            ForEach(model.capabilities.sorted { $0.label < $1.label }, id: \.self) { capability in
                Label {
                    Text(capability.label)
                } icon: {
                    Image(systemName: capability.icon)
                        .foregroundStyle(capability.color)
                }
            }
        }
    }

    var providerLogo: some View {
        Group {
            if let imageName = model.logoImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: model.provider.genericLogoSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var hasPricing: Bool {
        (model.inputCostPerToken ?? 0) > 0 || (model.outputCostPerToken ?? 0) > 0
    }
}

// MARK: - LLMModel.Mode display name

private extension LLMModel.Mode {
    var displayName: String {
        switch self {
        case .chat: String(localized: "Chat")
        case .completion: String(localized: "Completion")
        case .embedding: String(localized: "Embedding")
        case .imageGeneration: String(localized: "Image Generation")
        case .audioTranscription: String(localized: "Speech to Text")
        case .audioSpeech: String(localized: "Text to Speech")
        case .unknown: String(localized: "Unknown")
        }
    }
}

#Preview {
    ModelDetailView(
        model: LLMModel(
            id: "gpt-4o",
            ownedBy: "openai",
            capabilities: [.vision, .functionCalling, .jsonSchema],
            provider: .cloud,
            mode: .chat,
            providerName: "OpenAI",
            maxInputTokens: 128_000,
            maxOutputTokens: 16_384,
            inputCostPerToken: 0.0000025,
            outputCostPerToken: 0.00001
        )
    )
}
