//
//  AppleSpeechRecognitionManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
import Speech

protocol AppleSpeechRecognitionManagerProtocol: Sendable {
    func transcribe(audioFileURL: URL) async throws -> String
}

// Safety: SFSpeechRecognizer is used from a single async context per call.
final class AppleSpeechRecognitionManager: AppleSpeechRecognitionManagerProtocol, @unchecked Sendable {
    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> String {
        let status = await requestAuthorization()
        guard status == .authorized else {
            throw AppleSpeechError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw AppleSpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

// MARK: - Private

private extension AppleSpeechRecognitionManager {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - AppleSpeechError

enum AppleSpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            String(localized: "Speech recognition permission was not granted.")
        case .recognizerUnavailable:
            String(localized: "Speech recognition is not available on this device.")
        }
    }
}
