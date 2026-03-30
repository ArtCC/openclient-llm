//
//  APIError.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum APIError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case networkError(String)
    case serverUnreachable
    case unauthorized
    case rateLimited
    case streamingError(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "The server URL is not valid.")
        case .invalidResponse:
            String(localized: "The server returned an invalid response.")
        case .httpError(let statusCode):
            String(localized: "Server error (code \(statusCode)).")
        case .decodingError:
            String(localized: "Could not read the server response.")
        case .networkError(let message):
            message
        case .serverUnreachable:
            String(localized: "The server is not reachable.")
        case .unauthorized:
            String(localized: "Invalid API key. Please check your credentials.")
        case .rateLimited:
            String(localized: "Too many requests. Please try again later.")
        case .streamingError(let message):
            message
        }
    }
}
