//
//  PlayAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@MainActor
protocol PlayAudioUseCaseProtocol: AnyObject {
    func play(data: Data, messageId: UUID) async
    func stop()
}

@MainActor
final class PlayAudioUseCase: PlayAudioUseCaseProtocol {
    // MARK: - Properties

    private let manager: AudioPlayerManager

    // MARK: - Init

    init(manager: AudioPlayerManager = AudioPlayerManager()) {
        self.manager = manager
    }

    // MARK: - Execute

    func play(data: Data, messageId: UUID) async {
        manager.play(data: data, messageId: messageId)
        while manager.isPlaying {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    func stop() {
        manager.stop()
    }
}
