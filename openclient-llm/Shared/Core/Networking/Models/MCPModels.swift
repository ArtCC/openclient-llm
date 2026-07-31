//
//  MCPModels.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - MCPServerInfo

nonisolated struct MCPServerInfo: Codable, Equatable, Identifiable, Sendable {
    let serverId: String
    let serverName: String
    let description: String?
    let allowedTools: [String]?

    var id: String { serverId }
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

    var prefixedName: String { "\(serverName)-\(name)" }
    var id: String { "\(serverId)-\(name)" }

    func withServer(_ server: MCPServerInfo) -> MCPToolInfo {
        MCPToolInfo(
            name: name,
            description: description,
            serverId: server.serverId,
            serverName: server.serverName,
            inputSchema: inputSchema
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
        // LiteLLM may omit the schema or return a provider-specific placeholder.
        // Tool discovery must remain usable when optional schema data is malformed.
        inputSchema = try? container.decode(MCPJSONSchema.self, forKey: .inputSchema)
        serverId = ""
        serverName = ""
    }

    init(name: String, description: String?, serverId: String, serverName: String, inputSchema: MCPJSONSchema?) {
        self.name = name
        self.description = description
        self.serverId = serverId
        self.serverName = serverName
        self.inputSchema = inputSchema
    }
}

// MARK: - MCPJSONSchema

final class MCPJSONSchema: Codable, Equatable, @unchecked Sendable {
    // Safety: Immutable after initialization. All properties are `let`.
    let type: String?
    let properties: [String: MCPJSONSchema]?
    let required: [String]?
    let description: String?
    let items: MCPJSONSchema?
    let `enum`: [String]?

    init(
        type: String?,
        properties: [String: MCPJSONSchema]?,
        required: [String]?,
        description: String?,
        items: MCPJSONSchema?,
        `enum`: [String]?
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
        self.items = items
        self.enum = `enum`
    }

    nonisolated static func == (lhs: MCPJSONSchema, rhs: MCPJSONSchema) -> Bool {
        lhs.type == rhs.type
            && lhs.properties == rhs.properties
            && lhs.required == rhs.required
            && lhs.description == rhs.description
            && lhs.items == rhs.items
            && lhs.`enum` == rhs.`enum`
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
    case double(Double)
    case bool(Bool)
    case array([MCPCallValue])
    case object([String: MCPCallValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
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
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
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
