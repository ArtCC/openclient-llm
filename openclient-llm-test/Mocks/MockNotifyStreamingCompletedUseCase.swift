//
//  MockNotifyStreamingCompletedUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 27/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockNotifyStreamingCompletedUseCase: NotifyStreamingCompletedUseCaseProtocol {
    private(set) var completionCallCount = 0
    private(set) var expirationCallCount = 0

    func execute() {
        completionCallCount += 1
    }

    func executeExpired() {
        expirationCallCount += 1
    }
}
