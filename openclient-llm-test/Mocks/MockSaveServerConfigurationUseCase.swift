//
//  MockSaveServerConfigurationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSaveServerConfigurationUseCase: SaveServerConfigurationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var savedServerURL: String?
    var savedAPIKey: String?

    // MARK: - Execute

    func execute(serverURL: String, apiKey: String) {
        savedServerURL = serverURL
        savedAPIKey = apiKey
    }
}
