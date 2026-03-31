//
//  ModelParameters.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ModelParameters: Equatable, Sendable, Codable {
    // MARK: - Properties

    var temperature: Double?
    var maxTokens: Int?
    var topP: Double?

    // MARK: - Init

    init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
    }

    // MARK: - Static

    static let `default` = ModelParameters()

    var hasCustomValues: Bool {
        temperature != nil || maxTokens != nil || topP != nil
    }
}
