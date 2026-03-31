//
//  TokenUsage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct TokenUsage: Equatable, Sendable, Codable {
    // MARK: - Properties

    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    // MARK: - Init

    init(
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
