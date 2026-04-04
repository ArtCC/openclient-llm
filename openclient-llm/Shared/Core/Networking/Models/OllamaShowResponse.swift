//
//  OllamaShowResponse.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct OllamaShowRequest: Encodable, Sendable {
    let model: String
}

nonisolated struct OllamaShowResponse: Decodable, Sendable {
    // MARK: - Properties

    /// e.g. ["completion", "vision", "tools", "embed", "insert"]
    let capabilities: [String]?
    let details: Details?

    struct Details: Decodable, Sendable {
        let family: String?
        let parameterSize: String?
    }
}
