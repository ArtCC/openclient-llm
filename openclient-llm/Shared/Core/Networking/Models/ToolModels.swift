//
//  ToolModels.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ToolCall

nonisolated struct ToolCall: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let type: String
    let function: ToolCallFunction
}

// MARK: - ToolCallFunction

nonisolated struct ToolCallFunction: Codable, Sendable, Equatable {
    let name: String
    let arguments: String
}

// MARK: - ToolDefinition

nonisolated struct ToolDefinition: Codable, Sendable {
    let type: String
    let function: ToolFunctionDefinition
}

// MARK: - ToolFunctionDefinition

nonisolated struct ToolFunctionDefinition: Codable, Sendable {
    let name: String
    let description: String
    let parameters: ToolParameters
}

// MARK: - ToolParameters

nonisolated struct ToolParameters: Codable, Sendable {
    let type: String
    let properties: [String: ToolParameterProperty]
    let required: [String]
}

// MARK: - ToolParameterProperty

// Safety: Immutable after initialization. All properties are `let`.
nonisolated final class ToolParameterProperty: Codable, @unchecked Sendable {
    let type: String
    let description: String
    let properties: [String: ToolParameterProperty]?
    let items: ToolParameterProperty?
    let required: [String]?
    let `enum`: [String]?

    init(
        type: String,
        description: String,
        properties: [String: ToolParameterProperty]? = nil,
        items: ToolParameterProperty? = nil,
        required: [String]? = nil,
        `enum`: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.items = items
        self.required = required
        self.enum = `enum`
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case properties
        case items
        case required
        case `enum`
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decode(String.self, forKey: .description)
        properties = try container.decodeIfPresent(
            [String: ToolParameterProperty].self,
            forKey: .properties
        )
        items = try container.decodeIfPresent(ToolParameterProperty.self, forKey: .items)
        required = try container.decodeIfPresent([String].self, forKey: .required)
        self.enum = try container.decodeIfPresent([String].self, forKey: .enum)
    }
}
