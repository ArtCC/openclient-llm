//
//  MockSynchronizeAppDataUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSynchronizeAppDataUseCase: SynchronizeAppDataUseCaseProtocol, @unchecked Sendable {
    var result = AppSynchronizationResult(outcomes: [
        .conversations: .synchronized,
        .profile: .synchronized,
        .memory: .synchronized,
        .promptTemplates: .synchronized
    ])
    var executeCallCount = 0
    var cancelCallCount = 0
    var cancelHandler: (@Sendable () async -> Void)?

    func execute() async -> AppSynchronizationResult {
        executeCallCount += 1
        return result
    }

    func cancel() async {
        cancelCallCount += 1
        await cancelHandler?()
    }
}
