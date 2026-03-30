//
//  MockCheckOnboardingUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//

import Foundation

final class MockCheckOnboardingUseCase: CheckOnboardingUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Bool = false

    // MARK: - Execute

    func execute() -> Bool {
        result
    }
}
