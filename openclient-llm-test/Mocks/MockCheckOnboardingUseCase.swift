//
//  MockCheckOnboardingUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
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
