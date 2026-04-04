//
//  MockAppleSpeechRecognitionManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockAppleSpeechRecognitionManager: AppleSpeechRecognitionManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<String, Error> = .success("Apple transcribed text")
    var transcribeCalled = false
    var lastURL: URL?

    // MARK: - Public

    func transcribe(audioFileURL: URL) async throws -> String {
        transcribeCalled = true
        lastURL = audioFileURL
        return try result.get()
    }
}
