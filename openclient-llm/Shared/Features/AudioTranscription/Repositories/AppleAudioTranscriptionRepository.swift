//
//  AppleAudioTranscriptionRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct AppleAudioTranscriptionRepository: AudioTranscriptionRepositoryProtocol {
    // MARK: - Properties

    private let manager: AppleSpeechRecognitionManagerProtocol

    // MARK: - Init

    init(manager: AppleSpeechRecognitionManagerProtocol = AppleSpeechRecognitionManager.shared) {
        self.manager = manager
    }

    // MARK: - Public

    func transcribe(audioData: Data, model: String, language: String?, fileName: String) async throws -> String {
        LogManager.info("AppleSTT transcribe data=\(audioData.count) bytes")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple_stt_\(UUID().uuidString).m4a")
        try audioData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await manager.transcribe(audioFileURL: url)
        LogManager.success("AppleSTT done chars=\(text.count)")
        return text
    }
}
