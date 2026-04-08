//
//  RecordAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@MainActor
protocol RecordAudioUseCaseProtocol: AnyObject {
    var recordingDuration: TimeInterval { get }

    func startRecording()
    func stopRecording() -> (data: Data?, duration: TimeInterval)
    func cancelRecording()
}

@MainActor
final class RecordAudioUseCase: RecordAudioUseCaseProtocol {
    // MARK: - Properties

    private let manager: AudioRecorderManagerProtocol

    var recordingDuration: TimeInterval { manager.recordingDuration }

    // MARK: - Init

    init(manager: AudioRecorderManagerProtocol = AudioRecorderManager()) {
        self.manager = manager
    }

    // MARK: - Execute

    func startRecording() {
        manager.startRecording()
    }

    func stopRecording() -> (data: Data?, duration: TimeInterval) {
        manager.stopRecording()
    }

    func cancelRecording() {
        manager.cancelRecording()
    }
}
