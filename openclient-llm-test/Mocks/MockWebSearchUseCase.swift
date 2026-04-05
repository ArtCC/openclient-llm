//
//  MockWebSearchUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockWebSearchUseCase: WebSearchUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<[LiteLLMSearchResult], Error> = .success([])
    var executeCallCount: Int = 0
    var lastQuery: String?

    // MARK: - Execute

    func execute(query: String) async throws -> [LiteLLMSearchResult] {
        executeCallCount += 1
        lastQuery = query
        return try result.get()
    }
}
