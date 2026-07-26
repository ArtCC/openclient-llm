//
//  MCPTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct MCPTool: ChatToolProtocol {
    // MARK: - Properties

    let serverId: String
    let toolName: String
    let rawName: String
    private let repository: MCPRepositoryProtocol

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: toolName,
                description: description,
                parameters: parameters
            )
        )
    }

    private let description: String
    private let parameters: ToolParameters

    // MARK: - Init

    init(
        serverId: String,
        toolName: String,
        rawName: String,
        description: String,
        parameters: ToolParameters,
        repository: MCPRepositoryProtocol = MCPRepository()
    ) {
        self.serverId = serverId
        self.toolName = toolName
        self.rawName = rawName
        self.description = description
        self.parameters = parameters
        self.repository = repository
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        let resultText = try await repository.executeTool(
            serverId: serverId,
            toolName: rawName,
            arguments: arguments
        )
        return ToolExecutionResult(text: resultText)
    }

    // MARK: - Factory

    static func toolParameters(from schema: MCPJSONSchema?) -> ToolParameters {
        guard let schema else {
            return ToolParameters(type: "object", properties: [:], required: [])
        }
        var properties: [String: ToolParameterProperty] = [:]
        for (key, prop) in schema.properties ?? [:] {
            let typeString = resolveTypeString(prop)
            properties[key] = ToolParameterProperty(
                type: typeString,
                description: prop.description ?? key
            )
        }
        return ToolParameters(
            type: schema.type ?? "object",
            properties: properties,
            required: schema.required ?? []
        )
    }

    // MARK: - Private

    private static func resolveTypeString(_ schema: MCPJSONSchema) -> String {
        if let type = schema.type {
            if type == "array", let items = schema.items {
                return "array of \(resolveTypeString(items))"
            }
            return type
        }
        return "string"
    }
}
