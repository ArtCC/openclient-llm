//
//  MockGenerateImageUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
@MainActor
final class MockGenerateImageUseCase: GenerateImageUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<GeneratedImage, Error>?
    var executeCalled = false

    // MARK: - Execute

    func execute(prompt: String, model: String, size: String, mode: LLMModel.Mode) async throws -> GeneratedImage {
        executeCalled = true
        guard let result else {
            return GeneratedImage(prompt: "", imageData: Data(), modelId: "")
        }
        return try result.get()
    }
}
