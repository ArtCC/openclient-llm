//
//  LLMModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct LLMModel: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: String
    let ownedBy: String
    var capabilities: [Capability]
    var provider: Provider
    var mode: Mode
    var providerName: String

    // MARK: - Init

    init(
        id: String,
        ownedBy: String = "",
        capabilities: [Capability] = [],
        provider: Provider = .cloud,
        mode: Mode = .chat,
        providerName: String = ""
    ) {
        self.id = id
        self.ownedBy = ownedBy
        self.capabilities = capabilities
        self.provider = provider
        self.mode = mode
        self.providerName = providerName
    }
}

// MARK: - Provider

extension LLMModel {
    enum Provider: Equatable, Sendable {
        case local
        case cloud

        // MARK: - Properties

        var label: String {
            switch self {
            case .local: String(localized: "Local")
            case .cloud: String(localized: "Cloud")
            }
        }

        var icon: String {
            switch self {
            case .local: "desktopcomputer"
            case .cloud: "cloud"
            }
        }

        var genericLogoSystemName: String {
            switch self {
            case .local: "cpu.fill"
            case .cloud: "sparkles"
            }
        }

        // MARK: - Static

        static func from(_ providerString: String?) -> Provider {
            let localProviders: Set<String> = ["ollama", "lm_studio", "llamacpp"]
            guard let value = providerString?.lowercased() else { return .cloud }
            return localProviders.contains(value) ? .local : .cloud
        }

        static func displayName(from providerString: String?) -> String {
            guard let key = providerString?.lowercased() else { return "" }
            let mapping: [String: String] = [
                "openai": "OpenAI",
                "anthropic": "Anthropic",
                "ollama": "Ollama",
                "vertex_ai": "Google",
                "vertex_ai_beta": "Google",
                "gemini": "Google",
                "deepseek": "DeepSeek",
                "cohere": "Cohere",
                "mistral": "Mistral",
                "groq": "Groq",
                "azure": "Azure",
                "azure_ai": "Azure",
                "bedrock": "AWS Bedrock",
                "lm_studio": "LM Studio",
                "llamacpp": "llama.cpp",
                "replicate": "Replicate",
                "huggingface": "Hugging Face",
                "together_ai": "Together AI",
                "fireworks_ai": "Fireworks AI",
                "perplexity": "Perplexity",
                "anyscale": "Anyscale",
                "xai": "xAI"
            ]
            return mapping[key] ?? providerString ?? ""
        }
    }
}

// MARK: - Mode

extension LLMModel {
    enum Mode: String, Equatable, Sendable {
        case chat
        case completion
        case embedding
        case imageGeneration = "image_generation"
        case audioTranscription = "audio_transcription"
        case audioSpeech = "audio_speech"
        case unknown

        // MARK: - Init

        init(rawString: String?) {
            guard let rawString else {
                self = .chat
                return
            }
            self = Mode(rawValue: rawString) ?? .unknown
        }
    }
}

// MARK: - Capability

extension LLMModel {
    enum Capability: String, Equatable, Sendable, CaseIterable {
        case vision
        case functionCalling
        case parallelFunctionCalling
        case jsonSchema

        // MARK: - Properties

        var label: String {
            switch self {
            case .vision:
                String(localized: "Vision")
            case .functionCalling:
                String(localized: "Tools")
            case .parallelFunctionCalling:
                String(localized: "Parallel Tools")
            case .jsonSchema:
                String(localized: "JSON Mode")
            }
        }

        var icon: String {
            switch self {
            case .vision: "eye"
            case .functionCalling: "wrench.and.screwdriver"
            case .parallelFunctionCalling: "square.stack.3d.up"
            case .jsonSchema: "curlybraces"
            }
        }

        var color: Color {
            switch self {
            case .vision: .purple
            case .functionCalling: .orange
            case .parallelFunctionCalling: .cyan
            case .jsonSchema: .green
            }
        }
    }
}
