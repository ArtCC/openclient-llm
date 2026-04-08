//
//  MockResolveAudioModelIdsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockResolveAudioModelIdsUseCase: ResolveAudioModelIdsUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: AudioModelIds = AudioModelIds(
        ttsModelId: nil,
        transcriptionModelId: "apple-speech-recognition"
    )

    // MARK: - ResolveAudioModelIdsUseCaseProtocol

    func execute(from models: [LLMModel]) -> AudioModelIds {
        result
    }
}
