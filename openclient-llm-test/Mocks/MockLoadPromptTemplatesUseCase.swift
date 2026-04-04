//
//  MockLoadPromptTemplatesUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockLoadPromptTemplatesUseCase: LoadPromptTemplatesUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<[PromptTemplate], Error> = .success([])
    var executeCallCount = 0

    // MARK: - Execute

    func execute() throws -> [PromptTemplate] {
        executeCallCount += 1
        return try result.get()
    }
}
