//
//  MockGetSelectedModelUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 07/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockGetSelectedModelUseCase: GetSelectedModelUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var modelId: String = ""

    // MARK: - Execute

    func execute() -> String {
        modelId
    }
}
