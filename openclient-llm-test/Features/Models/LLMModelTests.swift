//
//  LLMModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class LLMModelTests: XCTestCase {
    // MARK: - Tests — Provider.from

    func test_providerFrom_localProvider_ollama_returnsLocal() {
        XCTAssertEqual(LLMModel.Provider.from("ollama"), .local)
    }

    func test_providerFrom_localProvider_vllm_returnsLocal() {
        XCTAssertEqual(LLMModel.Provider.from("vllm"), .local)
    }

    func test_providerFrom_localProvider_lmstudio_returnsLocal() {
        XCTAssertEqual(LLMModel.Provider.from("lm_studio"), .local)
    }

    func test_providerFrom_localProvider_llamacpp_returnsLocal() {
        XCTAssertEqual(LLMModel.Provider.from("llamacpp"), .local)
    }

    func test_providerFrom_localProvider_hostedVllm_returnsLocal() {
        XCTAssertEqual(LLMModel.Provider.from("hosted_vllm"), .local)
    }

    func test_providerFrom_cloudProvider_openai_returnsCloud() {
        XCTAssertEqual(LLMModel.Provider.from("openai"), .cloud)
    }

    func test_providerFrom_cloudProvider_anthropic_returnsCloud() {
        XCTAssertEqual(LLMModel.Provider.from("anthropic"), .cloud)
    }

    func test_providerFrom_nil_returnsCloud() {
        XCTAssertEqual(LLMModel.Provider.from(nil), .cloud)
    }

    func test_providerFrom_empty_returnsCloud() {
        XCTAssertEqual(LLMModel.Provider.from(""), .cloud)
    }

    func test_providerFrom_unknown_returnsCloud() {
        XCTAssertEqual(LLMModel.Provider.from("unknown_provider"), .cloud)
    }

    func test_providerFrom_caseInsensitive() {
        XCTAssertEqual(LLMModel.Provider.from("OLLAMA"), .local)
    }

    // MARK: - Tests — Provider.displayName

    func test_displayName_openai_returnsOpenAI() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "openai"), "OpenAI")
    }

    func test_displayName_anthropic_returnsAnthropic() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "anthropic"), "Anthropic")
    }

    func test_displayName_vertexAI_returnsGoogle() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "vertex_ai"), "Google")
    }

    func test_displayName_gemini_returnsGoogle() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "gemini"), "Google")
    }

    func test_displayName_deepseek_returnsDeepSeek() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "deepseek"), "DeepSeek")
    }

    func test_displayName_ollama_returnsOllama() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "ollama"), "Ollama")
    }

    func test_displayName_vllm_returnsVLLM() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "vllm"), "vLLM")
    }

    func test_displayName_nil_returnsEmpty() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: nil), "")
    }

    func test_displayName_unknown_returnsOriginal() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "CustomProvider"), "CustomProvider")
    }

    func test_displayName_caseInsensitive() {
        XCTAssertEqual(LLMModel.Provider.displayName(from: "OPENAI"), "OpenAI")
    }

    // MARK: - Tests — Provider label

    func test_providerLabel_local_returnsLocalizedString() {
        XCTAssertFalse(LLMModel.Provider.local.label.isEmpty)
    }

    func test_providerLabel_cloud_returnsLocalizedString() {
        XCTAssertFalse(LLMModel.Provider.cloud.label.isEmpty)
    }

    // MARK: - Tests — Provider icon

    func test_providerIcon_local_returnsNonEmpty() {
        XCTAssertFalse(LLMModel.Provider.local.icon.isEmpty)
    }

    func test_providerIcon_cloud_returnsNonEmpty() {
        XCTAssertFalse(LLMModel.Provider.cloud.icon.isEmpty)
    }

    // MARK: - Tests — Provider genericLogoSystemName

    func test_genericLogoSystemName_local_returnsNonEmpty() {
        XCTAssertFalse(LLMModel.Provider.local.genericLogoSystemName.isEmpty)
    }

    func test_genericLogoSystemName_cloud_returnsNonEmpty() {
        XCTAssertFalse(LLMModel.Provider.cloud.genericLogoSystemName.isEmpty)
    }

    // MARK: - Tests — Mode.init(rawString:)

    func test_modeRawString_chat_returnsChat() {
        XCTAssertEqual(LLMModel.Mode(rawString: "chat"), .chat)
    }

    func test_modeRawString_completion_returnsCompletion() {
        XCTAssertEqual(LLMModel.Mode(rawString: "completion"), .completion)
    }

    func test_modeRawString_embedding_returnsEmbedding() {
        XCTAssertEqual(LLMModel.Mode(rawString: "embedding"), .embedding)
    }

    func test_modeRawString_imageGeneration_returnsImageGeneration() {
        XCTAssertEqual(LLMModel.Mode(rawString: "image_generation"), .imageGeneration)
    }

    func test_modeRawString_audioTranscription_returnsAudioTranscription() {
        XCTAssertEqual(LLMModel.Mode(rawString: "audio_transcription"), .audioTranscription)
    }

    func test_modeRawString_audioSpeech_returnsAudioSpeech() {
        XCTAssertEqual(LLMModel.Mode(rawString: "audio_speech"), .audioSpeech)
    }

    func test_modeRawString_nil_returnsChat() {
        XCTAssertEqual(LLMModel.Mode(rawString: nil), .chat)
    }

    func test_modeRawString_unknown_returnsUnknown() {
        XCTAssertEqual(LLMModel.Mode(rawString: "some_new_mode"), .unknown)
    }

    // MARK: - Tests — logoImageName

    func test_logoImageName_openai_returnsExpected() {
        let model = LLMModel(id: "gpt-4", providerName: "OpenAI")
        XCTAssertEqual(model.logoImageName, "openai")
    }

    func test_logoImageName_anthropic_returnsExpected() {
        let model = LLMModel(id: "claude", providerName: "Anthropic")
        XCTAssertEqual(model.logoImageName, "anthropic")
    }

    func test_logoImageName_ollama_returnsExpected() {
        let model = LLMModel(id: "llama3", providerName: "Ollama")
        XCTAssertEqual(model.logoImageName, "ollama")
    }

    func test_logoImageName_google_returnsExpected() {
        let model = LLMModel(id: "gemini-pro", providerName: "Google")
        XCTAssertEqual(model.logoImageName, "gemini")
    }

    func test_logoImageName_deepseek_returnsExpected() {
        let model = LLMModel(id: "deepseek-chat", providerName: "DeepSeek")
        XCTAssertEqual(model.logoImageName, "deepseek")
    }

    func test_logoImageName_vllm_returnsExpected() {
        let model = LLMModel(id: "vllm-model", providerName: "vLLM")
        XCTAssertEqual(model.logoImageName, "vllm")
    }

    func test_logoImageName_unknown_returnsNil() {
        let model = LLMModel(id: "custom-model", providerName: "SomeProvider")
        XCTAssertNil(model.logoImageName)
    }

    // MARK: - Tests — isAppleNative

    func test_isAppleNative_appleSpeechRecognition_returnsTrue() {
        let model = LLMModel.appleSpeechRecognition
        XCTAssertTrue(model.isAppleNative)
    }

    func test_isAppleNative_otherModel_returnsFalse() {
        let model = LLMModel(id: "gpt-4")
        XCTAssertFalse(model.isAppleNative)
    }

    // MARK: - Tests — appleSpeechRecognition

    func test_appleSpeechRecognition_hasExpectedId() {
        XCTAssertEqual(LLMModel.appleSpeechRecognition.id, "apple-speech-recognition")
    }

    func test_appleSpeechRecognition_isLocalProvider() {
        XCTAssertEqual(LLMModel.appleSpeechRecognition.provider, .local)
    }

    func test_appleSpeechRecognition_isAudioTranscriptionMode() {
        XCTAssertEqual(LLMModel.appleSpeechRecognition.mode, .audioTranscription)
    }

    // MARK: - Tests — Capability

    func test_capability_allCases_hasExpectedCount() {
        XCTAssertEqual(LLMModel.Capability.allCases.count, 9)
    }

    func test_capability_eachCase_hasNonEmptyLabel() {
        for capability in LLMModel.Capability.allCases {
            XCTAssertFalse(capability.label.isEmpty, "\(capability) should have label")
        }
    }

    func test_capability_eachCase_hasNonEmptyIcon() {
        for capability in LLMModel.Capability.allCases {
            XCTAssertFalse(capability.icon.isEmpty, "\(capability) should have icon")
        }
    }
}
