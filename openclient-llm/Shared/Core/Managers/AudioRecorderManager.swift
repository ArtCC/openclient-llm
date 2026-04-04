//
//  AudioRecorderManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AVFoundation
import Foundation

@Observable
@MainActor
final class AudioRecorderManager {
    // MARK: - Properties

    private(set) var isRecording: Bool = false
    private(set) var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startTime: Date?

    // MARK: - Public

    func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        #if os(iOS)
        configureAudioSession()
        #endif

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            recordingURL = url
            startTime = Date()
            isRecording = true
            startDurationTracking()
        } catch {
            LogManager.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording(completion: @MainActor (Data?, TimeInterval) -> Void) {
        guard let recorder = audioRecorder, recorder.isRecording else {
            completion(nil, 0)
            return
        }

        recorder.stop()
        isRecording = false
        recordingDuration = 0

        #if os(iOS)
        deactivateAudioSession()
        #endif

        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0

        guard let url = recordingURL else {
            completion(nil, 0)
            return
        }

        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
        audioRecorder = nil
        startTime = nil

        completion(data, duration)
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
        isRecording = false
        recordingDuration = 0
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        audioRecorder = nil
        startTime = nil
        #if os(iOS)
        deactivateAudioSession()
        #endif
    }
}

// MARK: - Private

private extension AudioRecorderManager {
    func startDurationTracking() {
        Task {
            while isRecording {
                try? await Task.sleep(for: .milliseconds(500))
                recordingDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
            }
        }
    }

    #if os(iOS)
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            LogManager.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            LogManager.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    #endif
}
