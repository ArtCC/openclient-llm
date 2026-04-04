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
    @MainActor
    func transcribe(audioFileURL: URL) async throws -> String
}

/// Wraps SFSpeechRecognizer for file-based transcription.
///
/// The class is @MainActor because SFSpeechRecognizer must be created and driven
/// from the main thread. Storing recognizer, task and continuation as retained
/// properties prevents the three root causes of the previous crash:
///   1. recognizer going out of scope before the callback fires (EXC_BAD_ACCESS)
///   2. SFSpeechRecognitionTask being released before it delivers a result
///   3. data-race on a captured `var` guard between concurrent callback invocations
@MainActor
final class AppleSpeechRecognitionManager: AppleSpeechRecognitionManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private var recognizer: SFSpeechRecognizer?
    private var currentTask: SFSpeechRecognitionTask?
    private var pendingContinuation: CheckedContinuation<String, Error>?

    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> String {
        let status = await requestAuthorization()
        guard status == .authorized else {
            throw AppleSpeechError.notAuthorized
        }

        // Cancel any stale operation from a previous (unexpected) call.
        resetState()

        let rec = SFSpeechRecognizer()
        guard let rec, rec.isAvailable else {
            throw AppleSpeechError.recognizerUnavailable
        }
        recognizer = rec

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            currentTask = rec.recognitionTask(with: request) { [weak self] result, error in
                // Dispatch to @MainActor via a Task so the callback is always
                // processed on the main actor regardless of which thread the
                // Speech framework uses to deliver it.
                Task { @MainActor [weak self] in
                    self?.handleResult(result: result, error: error)
                }
            }
        }
    }
}

// MARK: - Private

private extension AppleSpeechRecognitionManager {
    func handleResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Guard against the Speech framework calling the handler more than once.
        // Setting pendingContinuation to nil before resuming prevents double-resume.
        guard let cont = pendingContinuation else { return }
        pendingContinuation = nil
        resetState()

        if let error {
            cont.resume(throwing: error)
        } else if let result, result.isFinal {
            cont.resume(returning: result.bestTranscription.formattedString)
        } else {
            // Defensive: callback with no error and no final result is unexpected
            // but must not leave the continuation suspended forever.
            cont.resume(throwing: AppleSpeechError.recognizerUnavailable)
        }
    }

    func resetState() {
        currentTask?.cancel()
        currentTask = nil
        recognizer = nil
    }

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
