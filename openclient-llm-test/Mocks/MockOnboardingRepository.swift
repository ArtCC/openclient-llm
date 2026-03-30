//
//  MockOnboardingRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockOnboardingRepository: OnboardingRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    var testConnectionResult: Result<Void, Error> = .success(())

    // MARK: - Public

    func testConnection(serverURL: String, apiKey: String) async throws {
        try testConnectionResult.get()
    }
}
