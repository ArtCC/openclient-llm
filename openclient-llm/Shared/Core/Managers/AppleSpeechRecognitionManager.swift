//
//  AppleSpeechRecognitionManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
import os
import Speech

protocol AppleSpeechRecognitionManagerProtocol: Sendable {
    @MainActor
    func transcribe(audioFileURL: URL) async throws -> String
}

@MainActor
final class AppleSpeechRecognitionManager: AppleSpeechRecognitionManagerProtocol, @unchecked Sendable {
    // MARK: - Shared

    static let shared = AppleSpeechRecognitionManager()

    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> String {
        try await requestAuthorization()

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw AppleSpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false

        // Thread-safe guard to ensure the continuation is resumed exactly once.
        let resumed = OSAllocatedUnfairLock(initialState: false)

        return try await withCheckedThrowingContinuation { continuation in
            // recognizer is a local of the suspended async frame, so it stays
            // alive until the continuation resumes and this function returns.
            recognizer.recognitionTask(with: request) { result, error in
                let alreadyResumed = resumed.withLock { state -> Bool in
                    if state { return true }
                    state = true
                    return false
                }
                guard !alreadyResumed else { return }

                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else {
                    continuation.resume(throwing: AppleSpeechError.recognizerUnavailable)
                }
            }
        }
    }
}

// MARK: - Private

private extension AppleSpeechRecognitionManager {
    func requestAuthorization() async throws {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
        guard status == .authorized else {
            throw AppleSpeechError.notAuthorized
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
