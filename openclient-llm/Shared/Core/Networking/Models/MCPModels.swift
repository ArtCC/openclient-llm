//
//  MCPModels.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

// MARK: - MCPServerInfo

nonisolated struct MCPServerInfo: Codable, Equatable, Identifiable, Sendable {
    let serverId: String
    let serverName: String
    let description: String?
    let allowedTools: [String]?

    var id: String { serverId }
    var displayName: String {
        MCPDisplayText.sanitize(
            serverName,
            fallback: String(localized: "MCP server"),
            maximumLength: 160
        )
    }
    var displayDescription: String? {
        description.map {
            MCPDisplayText.sanitize($0, fallback: displayName, maximumLength: 500)
        }
    }
}

// MARK: - MCP list responses

nonisolated struct MCPServersResponse: Decodable, Sendable {
    let data: [MCPServerInfo]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let data = try? container.decode([MCPServerInfo].self, forKey: .data) {
            self.data = data
            return
        }
        self.data = try [MCPServerInfo](from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

nonisolated struct MCPToolsResponse: Decodable, Sendable {
    let data: [MCPToolInfo]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let data = try? container.decode([MCPToolInfo].self, forKey: .data) {
            self.data = data
            return
        }
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let tools = try? container.decode([MCPToolInfo].self, forKey: .tools) {
            self.data = tools
            return
        }
        self.data = try [MCPToolInfo](from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case tools
    }
}

// MARK: - MCPToolInfo

nonisolated struct MCPToolInfo: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let description: String?
    let serverId: String
    let serverName: String
    let inputSchema: MCPJSONSchema?
    let rawInputSchemaData: Data?
    let isInputSchemaSupported: Bool

    var prefixedName: String {
        let digest = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return "mcp_\(digest.prefix(60))"
    }
    var legacyPrefixedName: String { "\(serverName)-\(name)" }
    var id: String { Self.identifier(serverId: serverId, name: name) }
    var legacyId: String { "\(serverId)-\(name)" }
    var displayName: String {
        MCPDisplayText.sanitize(
            name,
            fallback: String(localized: "External MCP tool"),
            maximumLength: 160
        )
    }
    var displayDescription: String? {
        description.map {
            MCPDisplayText.sanitize($0, fallback: displayName, maximumLength: 500)
        }
    }

    static func identifier(serverId: String, name: String) -> String {
        let encodedServerId = Data(serverId.utf8).base64EncodedString()
        let encodedName = Data(name.utf8).base64EncodedString()
        return "\(encodedServerId).\(encodedName)"
    }

    static func identity(from identifier: String) -> (serverId: String, name: String)? {
        let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2,
              let serverData = Data(base64Encoded: String(components[0])),
              let nameData = Data(base64Encoded: String(components[1])),
              let serverId = String(data: serverData, encoding: .utf8),
              let name = String(data: nameData, encoding: .utf8) else { return nil }
        return (serverId, name)
    }

    static func migratedEnabledToolIds(savedIds: [String], tools: [MCPToolInfo]) -> Set<String> {
        let currentIds = Set(tools.map(\.id))
        var legacyCandidates: [String: Set<String>] = [:]
        for tool in tools {
            for legacyIdentifier in [tool.prefixedName, tool.legacyPrefixedName, tool.legacyId] {
                legacyCandidates[legacyIdentifier, default: []].insert(tool.id)
            }
        }
        let unambiguousLegacyIds = legacyCandidates.reduce(into: [String: String]()) { result, entry in
            if entry.value.count == 1 { result[entry.key] = entry.value.first }
        }
        return Set(savedIds.compactMap { savedId in
            currentIds.contains(savedId) ? savedId : unambiguousLegacyIds[savedId]
        })
    }

    func withServer(_ server: MCPServerInfo) -> MCPToolInfo {
        MCPToolInfo(
            name: name,
            description: description,
            serverId: server.serverId,
            serverName: server.serverName,
            inputSchema: inputSchema,
            rawInputSchemaData: rawInputSchemaData,
            isInputSchemaSupported: isInputSchemaSupported
        )
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        let hasInputSchema = container.contains(.inputSchema)
            && (try? container.decodeNil(forKey: .inputSchema)) == false
        if hasInputSchema {
            let rawInputSchema = try? container.decode(MCPCallValue.self, forKey: .inputSchema)
            inputSchema = try? container.decode(MCPJSONSchema.self, forKey: .inputSchema)
            rawInputSchemaData = rawInputSchema.flatMap(Self.canonicalData)
            isInputSchemaSupported = inputSchema != nil
                && rawInputSchema.map(Self.isSupportedInputSchema) == true
        } else {
            inputSchema = nil
            rawInputSchemaData = nil
            isInputSchemaSupported = true
        }
        serverId = ""
        serverName = ""
    }

    init(
        name: String,
        description: String?,
        serverId: String,
        serverName: String,
        inputSchema: MCPJSONSchema?,
        rawInputSchemaData: Data? = nil,
        isInputSchemaSupported: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.serverId = serverId
        self.serverName = serverName
        self.inputSchema = inputSchema
        self.rawInputSchemaData = rawInputSchemaData ?? inputSchema.flatMap(Self.canonicalData)
        if let isInputSchemaSupported {
            self.isInputSchemaSupported = isInputSchemaSupported
        } else if inputSchema == nil, rawInputSchemaData != nil {
            self.isInputSchemaSupported = false
        } else {
            self.isInputSchemaSupported = inputSchema.map { Self.isSupportedSchema($0, depth: 0) } ?? true
        }
    }

    private nonisolated static func canonicalData<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }

    private nonisolated static func isSupportedInputSchema(_ value: MCPCallValue) -> Bool {
        guard case .object(let schema) = value else { return false }
        if let type = schema["type"] {
            guard case .string(let typeName) = type, typeName == "object" else { return false }
        } else {
            let hasObjectShape = schema["properties"] != nil
                || schema["required"] != nil
                || schema["additionalProperties"] != nil
            guard hasObjectShape else { return false }
        }
        if let properties = schema["properties"] {
            guard case .object = properties else { return false }
        }
        return isStringArray(schema["required"])
    }

    private nonisolated static func isSupportedSchema(_ schema: MCPJSONSchema, depth: Int) -> Bool {
        guard depth <= 10 else { return false }
        if let type = schema.type,
           !supportedSchemaTypes.contains(type) || (depth == 0 && type != "object") { return false }
        if depth == 0, schema.type == nil, schema.items != nil || schema.enum != nil { return false }
        if let properties = schema.properties,
           !properties.values.allSatisfy({ isSupportedSchema($0, depth: depth + 1) }) { return false }
        if let items = schema.items, !isSupportedSchema(items, depth: depth + 1) { return false }
        if case .schema(let additionalSchema)? = schema.additionalProperties {
            return isSupportedSchema(additionalSchema, depth: depth + 1)
        }
        return true
    }

    private nonisolated static func isStringValue(_ value: MCPCallValue?) -> Bool {
        guard let value else { return true }
        if case .string = value { return true }
        return false
    }

    private nonisolated static func isStringArray(_ value: MCPCallValue?) -> Bool {
        guard let value else { return true }
        guard case .array(let values) = value else { return false }
        return values.allSatisfy { isStringValue($0) }
    }

    private nonisolated static let supportedSchemaTypes: Set<String> = [
        "object", "array", "string", "integer", "number", "boolean", "null"
    ]
}

// MARK: - MCPJSONSchema

// Safety: Immutable after initialization. All properties are `let`.
nonisolated final class MCPJSONSchema: Codable, Equatable, @unchecked Sendable {
    let type: String?
    let properties: [String: MCPJSONSchema]?
    let required: [String]?
    let description: String?
    let items: MCPJSONSchema?
    let `enum`: [String]?
    let additionalProperties: MCPAdditionalProperties?

    init(
        type: String?,
        properties: [String: MCPJSONSchema]?,
        required: [String]?,
        description: String?,
        items: MCPJSONSchema?,
        `enum`: [String]?,
        additionalProperties: MCPAdditionalProperties? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
        self.items = items
        self.enum = `enum`
        self.additionalProperties = additionalProperties
    }

    nonisolated static func == (lhs: MCPJSONSchema, rhs: MCPJSONSchema) -> Bool {
        lhs.type == rhs.type
            && lhs.properties == rhs.properties
            && lhs.required == rhs.required
            && lhs.description == rhs.description
            && lhs.items == rhs.items
            && lhs.`enum` == rhs.`enum`
            && lhs.additionalProperties == rhs.additionalProperties
    }
}

nonisolated indirect enum MCPAdditionalProperties: Codable, Equatable, Sendable {
    case allowed(Bool)
    case schema(MCPJSONSchema)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .allowed(value)
        } else {
            self = try .schema(container.decode(MCPJSONSchema.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .allowed(let value): try container.encode(value)
        case .schema(let schema): try container.encode(schema)
        }
    }
}

// MARK: - MCPCallRequest

nonisolated struct MCPCallRequest: Codable, Sendable {
    let serverId: String
    let name: String
    let arguments: [String: MCPCallValue]

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case name
        case arguments
    }
}

// MARK: - MCPCallValue

nonisolated indirect enum MCPCallValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case decimal(Decimal)
    case bool(Bool)
    case array([MCPCallValue])
    case object([String: MCPCallValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .decimal(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .decimal(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([MCPCallValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: MCPCallValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported MCPCallValue type"
            )
        }
    }
}

// MARK: - MCPCallResponse

nonisolated struct MCPCallResponse: Codable, Sendable {
    let content: [MCPContentItem]?
    let isError: Bool?
}

// MARK: - MCPContentItem

nonisolated struct MCPContentItem: Codable, Sendable {
    let type: String
    let text: String?
}
