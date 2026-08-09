//
//  MockRemoteConfigManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockRemoteConfigManager: RemoteConfigManagerProtocol, @unchecked Sendable {
    var result: Result<RemoteConfig, Error> = .failure(RemoteConfigManagerError.invalidResponse)

    func loadConfig() async throws -> RemoteConfig {
        try result.get()
    }
}
