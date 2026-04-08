//
//  MockSaveSelectedModelUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSaveSelectedModelUseCase: SaveSelectedModelUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var executeCalled = false
    var savedModelId: String?

    // MARK: - SaveSelectedModelUseCaseProtocol

    func execute(modelId: String?) {
        executeCalled = true
        savedModelId = modelId
    }
}
