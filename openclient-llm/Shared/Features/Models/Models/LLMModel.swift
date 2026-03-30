//
//  LLMModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct LLMModel: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: String
    let ownedBy: String
    var capabilities: [Capability]

    // MARK: - Init

    init(id: String, ownedBy: String = "", capabilities: [Capability] = []) {
        self.id = id
        self.ownedBy = ownedBy
        self.capabilities = capabilities
    }
}

// MARK: - Capability

extension LLMModel {
    enum Capability: String, Equatable, Sendable, CaseIterable {
        case vision
        case functionCalling
        case parallelFunctionCalling
        case jsonSchema

        // MARK: - Properties

        var label: String {
            switch self {
            case .vision:
                String(localized: "Vision")
            case .functionCalling:
                String(localized: "Tools")
            case .parallelFunctionCalling:
                String(localized: "Parallel Tools")
            case .jsonSchema:
                String(localized: "JSON Mode")
            }
        }

        var icon: String {
            switch self {
            case .vision: "eye"
            case .functionCalling: "wrench.and.screwdriver"
            case .parallelFunctionCalling: "square.stack.3d.up"
            case .jsonSchema: "curlybraces"
            }
        }

        var color: Color {
            switch self {
            case .vision: .purple
            case .functionCalling: .orange
            case .parallelFunctionCalling: .cyan
            case .jsonSchema: .green
            }
        }
    }
}
