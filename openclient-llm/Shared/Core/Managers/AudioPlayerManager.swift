//
//  AudioPlayerManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AVFoundation
import Foundation

@Observable
@MainActor
final class AudioPlayerManager: NSObject {
    // MARK: - Properties

    private(set) var isPlaying: Bool = false
    private(set) var playingMessageId: UUID?

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Public

    func play(data: Data, messageId: UUID) {
        stop()

        #if os(iOS)
        configureAudioSession()
        #endif

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            playingMessageId = messageId
        } catch {
            LogManager.error("Failed to play audio: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingMessageId = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            playingMessageId = nil
        }
    }
}

// MARK: - Private

private extension AudioPlayerManager {
    #if os(iOS)
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            LogManager.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    #endif
}
