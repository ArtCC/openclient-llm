//
//  MockResetAppDataUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockResetAppDataUseCase: ResetAppDataUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var executeCalled: Bool = false
    var executeError: Error?

    // MARK: - Execute

    func execute() async throws {
        executeCalled = true
        if let executeError { throw executeError }
    }
}
