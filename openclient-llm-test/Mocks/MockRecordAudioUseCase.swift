//
//  MockRecordAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockRecordAudioUseCase: RecordAudioUseCaseProtocol {
    // MARK: - Properties

    var recordingDuration: TimeInterval = 0

    var startRecordingCalled = false
    var stopRecordingCalled = false
    var cancelRecordingCalled = false

    var stopRecordingResult: (data: Data?, duration: TimeInterval) = (nil, 0.0)

    // MARK: - RecordAudioUseCaseProtocol

    func startRecording() {
        startRecordingCalled = true
    }

    func stopRecording() -> (data: Data?, duration: TimeInterval) {
        stopRecordingCalled = true
        return stopRecordingResult
    }

    func cancelRecording() {
        cancelRecordingCalled = true
    }
}
