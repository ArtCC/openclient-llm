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

nonisolated struct ToolParameterProperty: Codable, Sendable {
    let type: String
    let description: String
}
