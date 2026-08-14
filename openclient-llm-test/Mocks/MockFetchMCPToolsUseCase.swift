//
//  MockFetchMCPToolsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockFetchMCPToolsUseCase: FetchMCPToolsUseCaseProtocol, @unchecked Sendable {
    var result = MCPDiscoveryResult(servers: [], tools: [])
    var executeHandler: (@Sendable () async -> MCPDiscoveryResult)?
    var executeCallCount = 0

    func execute() async -> MCPDiscoveryResult {
        executeCallCount += 1
        if let executeHandler { return await executeHandler() }
        return result
    }
}
