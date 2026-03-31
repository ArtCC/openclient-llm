//
//  MockTranscribeAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockTranscribeAudioUseCase: TranscribeAudioUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<String, Error> = .success("Transcribed text")
    var executeCalled = false

    // MARK: - Execute

    func execute(audioData: Data, model: String, language: String?, fileName: String) async throws -> String {
        executeCalled = true
        return try result.get()
    }
}
