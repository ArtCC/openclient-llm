//
//  MockSetWebSearchEnabledUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSetWebSearchEnabledUseCase: SetWebSearchEnabledUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var executeCalled = false
    var lastSetValue: Bool?

    // MARK: - SetWebSearchEnabledUseCaseProtocol

    func execute(_ value: Bool) {
        executeCalled = true
        lastSetValue = value
    }
}
