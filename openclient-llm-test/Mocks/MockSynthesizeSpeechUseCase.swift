//
//  MockSynthesizeSpeechUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSynthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<Data, Error> = .success(Data())
    var executeCalled = false

    // MARK: - Execute

    func execute(text: String, model: String, voice: String) async throws -> Data {
        executeCalled = true
        return try result.get()
    }
}
