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
    private let inputSchema: MCPJSONSchema?

    // MARK: - Init

    init(
        serverId: String,
        toolName: String,
        rawName: String,
        description: String,
        parameters: ToolParameters,
        repository: MCPRepositoryProtocol = MCPRepository(),
        inputSchema: MCPJSONSchema? = nil
    ) {
        self.serverId = serverId
        self.toolName = toolName
        self.rawName = rawName
        self.description = description
        self.parameters = parameters
        self.repository = repository
        self.inputSchema = inputSchema
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        try validate(arguments: arguments)
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
            properties[key] = makeProperty(prop, fallbackDescription: key)
        }
        return ToolParameters(
            type: schema.type ?? "object",
            properties: properties,
            required: schema.required ?? []
        )
    }

    // MARK: - Private

    private static func makeProperty(
        _ schema: MCPJSONSchema,
        fallbackDescription: String
    ) -> ToolParameterProperty {
        let nestedProperties = schema.properties?.mapValues {
            makeProperty($0, fallbackDescription: "")
        }
        let nestedItems = schema.items.map {
            makeProperty($0, fallbackDescription: "")
        }
        return ToolParameterProperty(
            type: schema.type ?? "string",
            description: schema.description ?? fallbackDescription,
            properties: nestedProperties,
            items: nestedItems,
            required: schema.required,
            enum: schema.enum
        )
    }

    private func validate(arguments: String) throws {
        guard arguments.utf8.count <= 65_536,
              let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw MCPToolError.invalidArguments
        }
        guard let inputSchema else { return }
        guard validate(dictionary, against: inputSchema, depth: 0) else {
            throw MCPToolError.argumentsDoNotMatchSchema
        }
    }

    private func validate(_ value: Any, against schema: MCPJSONSchema, depth: Int) -> Bool {
        guard depth <= 10 else { return false }
        if let allowedValues = schema.enum,
           let stringValue = value as? String,
           !allowedValues.contains(stringValue) {
            return false
        }

        switch schema.type {
        case "object":
            return validateObject(value, against: schema, depth: depth)
        case "array":
            return validateArray(value, against: schema, depth: depth)
        default:
            return validatePrimitive(value, type: schema.type)
        }
    }

    private func validatePrimitive(_ value: Any, type: String?) -> Bool {
        switch type {
        case "string":
            return value is String
        case "integer":
            guard !(value is Bool), let number = value as? NSNumber else { return false }
            return number.doubleValue.rounded() == number.doubleValue
        case "number":
            return !(value is Bool) && value is NSNumber
        case "boolean":
            return value is Bool
        case "null":
            return value is NSNull
        default:
            return true
        }
    }

    private func validateObject(_ value: Any, against schema: MCPJSONSchema, depth: Int) -> Bool {
        guard let object = value as? [String: Any] else { return false }
        for requiredKey in schema.required ?? [] where object[requiredKey] == nil {
            return false
        }
        for (key, propertySchema) in schema.properties ?? [:] {
            if let property = object[key], !validate(property, against: propertySchema, depth: depth + 1) {
                return false
            }
        }
        return true
    }

    private func validateArray(_ value: Any, against schema: MCPJSONSchema, depth: Int) -> Bool {
        guard let array = value as? [Any] else { return false }
        guard let itemSchema = schema.items else { return true }
        return array.allSatisfy { validate($0, against: itemSchema, depth: depth + 1) }
    }
}

enum MCPToolError: LocalizedError, Sendable, Equatable {
    case invalidArguments
    case argumentsDoNotMatchSchema

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            String(localized: "The MCP tool arguments are not valid JSON.")
        case .argumentsDoNotMatchSchema:
            String(localized: "The MCP tool arguments do not match the tool schema.")
        }
    }
}
