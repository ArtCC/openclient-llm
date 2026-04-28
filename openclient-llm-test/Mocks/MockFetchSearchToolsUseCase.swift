//
//  MockFetchSearchToolsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockFetchSearchToolsUseCase: FetchSearchToolsUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<[SearchToolItem], Error> = .success([])
    var executeCallCount: Int = 0

    // MARK: - FetchSearchToolsUseCaseProtocol

    func execute() async throws -> [SearchToolItem] {
        executeCallCount += 1
        return try result.get()
    }
}
