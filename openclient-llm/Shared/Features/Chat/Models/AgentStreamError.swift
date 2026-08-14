//
//  AgentStreamError.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum AgentStreamError: LocalizedError, Sendable, Equatable {
    case timedOut
    case iterationLimitReached
    case invalidResponse
    case configurationChanged

    var errorDescription: String? {
        switch self {
        case .timedOut:
            String(localized: "The agent timed out before completing the response.")
        case .iterationLimitReached:
            String(localized: "The agent reached its maximum number of steps.")
        case .invalidResponse:
            String(localized: "The model returned an invalid agent response.")
        case .configurationChanged:
            String(localized: "The server configuration changed while the response was running.")
        }
    }
}
