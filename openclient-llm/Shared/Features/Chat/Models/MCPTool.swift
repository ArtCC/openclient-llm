//
//  MCPTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct MCPTool: MCPAuthorizableToolProtocol {
    // MARK: - Properties

    let serverId: String
    let toolName: String
    let rawName: String
    private let repository: MCPRepositoryProtocol
    private let isConfigurationCurrent: @MainActor @Sendable () -> Bool
    private let isEnabled: @MainActor @Sendable () -> Bool
    private let baseAuthorizationMetadata: MCPToolAuthorizationMetadata
    private let permissionProvider: @MainActor @Sendable () -> MCPToolPermission

    var authorizationMetadata: MCPToolAuthorizationMetadata {
        baseAuthorizationMetadata.withPermission(permissionProvider())
    }

    var isAvailableForAdvertisement: Bool {
        isEnabled() && isConfigurationCurrent()
    }

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
        inputSchema: MCPJSONSchema? = nil,
        serverName: String? = nil,
        permissionKey: String? = nil,
        permission: MCPToolPermission = .ask,
        permissionProvider: (@MainActor @Sendable () -> MCPToolPermission)? = nil,
        isEnabled: @escaping @MainActor @Sendable () -> Bool = { true },
        isConfigurationCurrent: @escaping @MainActor @Sendable () -> Bool = { true }
    ) {
        self.serverId = serverId
        self.toolName = toolName
        self.rawName = rawName
        self.description = description
        self.parameters = parameters
        self.repository = repository
        self.inputSchema = inputSchema
        self.isConfigurationCurrent = isConfigurationCurrent
        self.isEnabled = isEnabled
        self.permissionProvider = permissionProvider ?? { permission }
        let sanitizedName = MCPDisplayText.sanitize(
            rawName,
            fallback: String(localized: "External MCP tool"),
            maximumLength: 160
        )
        let sanitizedServerName = MCPDisplayText.sanitize(
            serverName ?? serverId,
            fallback: String(localized: "MCP server"),
            maximumLength: 160
        )
        let sanitizedDescription = MCPDisplayText.sanitize(
            description,
            fallback: sanitizedName,
            maximumLength: 500
        )
        self.baseAuthorizationMetadata = MCPToolAuthorizationMetadata(
            toolId: MCPToolInfo.identifier(serverId: serverId, name: rawName),
            displayName: sanitizedName,
            serverName: sanitizedServerName,
            toolDescription: sanitizedDescription,
            permissionKey: permissionKey ?? "\(serverId)-\(rawName)",
            permission: permission
        )
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        try validateBeforeExecution(arguments: arguments, approvedByUser: false)
        return try await executeRepository(arguments: arguments)
    }

    func executeAuthorized(arguments: String, approvedByUser: Bool) async throws -> ToolExecutionResult {
        try validateBeforeExecution(arguments: arguments, approvedByUser: approvedByUser)
        return try await executeRepository(arguments: arguments)
    }

    private func executeRepository(arguments: String) async throws -> ToolExecutionResult {
        try Task.checkCancellation()
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
            required: schema.required ?? [],
            additionalProperties: makeAdditionalProperties(schema.additionalProperties)
        )
    }

    // MARK: - Private

    func validateForAuthorization(arguments: String) throws {
        guard isEnabled() else { throw MCPToolError.toolDisabled }
        guard isConfigurationCurrent() else { throw MCPToolError.configurationChanged }
        try validate(arguments: arguments)
    }

    func validateBeforeExecution(arguments: String, approvedByUser: Bool) throws {
        try validateForAuthorization(arguments: arguments)
        let permission = permissionProvider()
        if approvedByUser {
            guard permission != .deny else { throw MCPToolError.authorizationChanged }
        } else {
            guard permission == .alwaysAllow else { throw MCPToolError.authorizationChanged }
        }
    }

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
            type: inferredType(for: schema),
            description: schema.description ?? fallbackDescription,
            properties: nestedProperties,
            items: nestedItems,
            required: schema.required,
            enum: schema.enum,
            additionalProperties: makeAdditionalProperties(schema.additionalProperties)
        )
    }

    private static func makeAdditionalProperties(
        _ additionalProperties: MCPAdditionalProperties?
    ) -> ToolAdditionalProperties? {
        switch additionalProperties {
        case .allowed(let value):
            .allowed(value)
        case .schema(let schema):
            .schema(makeProperty(schema, fallbackDescription: ""))
        case nil:
            nil
        }
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
        if let allowedValues = schema.enum {
            guard let stringValue = value as? String,
                  allowedValues.contains(stringValue) else { return false }
        }

        if schema.type == nil,
           schema.properties != nil || schema.required != nil || schema.additionalProperties != nil {
            return validateObject(value, against: schema, depth: depth)
        }
        if schema.type == nil, schema.items != nil {
            return validateArray(value, against: schema, depth: depth)
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
            return type == nil
        }
    }

    private func validateObject(_ value: Any, against schema: MCPJSONSchema, depth: Int) -> Bool {
        guard let object = value as? [String: Any] else { return false }
        let declaredProperties = schema.properties ?? [:]
        for requiredKey in schema.required ?? [] where object[requiredKey] == nil {
            return false
        }
        for (key, propertySchema) in declaredProperties {
            if let property = object[key], !validate(property, against: propertySchema, depth: depth + 1) {
                return false
            }
        }
        let additionalValues = object.filter { declaredProperties[$0.key] == nil }.map(\.value)
        switch schema.additionalProperties {
        case .allowed(false):
            return additionalValues.isEmpty
        case .schema(let additionalSchema):
            return additionalValues.allSatisfy {
                validate($0, against: additionalSchema, depth: depth + 1)
            }
        case .allowed(true), nil:
            break
        }
        return true
    }

    private func validateArray(_ value: Any, against schema: MCPJSONSchema, depth: Int) -> Bool {
        guard let array = value as? [Any] else { return false }
        guard let itemSchema = schema.items else { return true }
        return array.allSatisfy { validate($0, against: itemSchema, depth: depth + 1) }
    }

    private static func inferredType(for schema: MCPJSONSchema) -> String {
        if let type = schema.type { return type }
        if schema.properties != nil || schema.required != nil || schema.additionalProperties != nil {
            return "object"
        }
        if schema.items != nil { return "array" }
        return "string"
    }
}

enum MCPToolError: LocalizedError, Sendable, Equatable {
    case invalidArguments
    case argumentsDoNotMatchSchema
    case configurationChanged
    case toolDisabled
    case authorizationChanged

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            String(localized: "The MCP tool arguments are not valid JSON.")
        case .argumentsDoNotMatchSchema:
            String(localized: "The MCP tool arguments do not match the tool schema.")
        case .configurationChanged:
            String(localized: "The MCP server configuration changed. Request the tool again before executing it.")
        case .toolDisabled:
            String(localized: "The MCP tool was disabled before it could execute.")
        case .authorizationChanged:
            String(localized: "The MCP tool permission changed before it could execute.")
        }
    }
}
