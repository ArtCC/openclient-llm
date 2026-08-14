//
//  MCPToolAuthorization.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol MCPAuthorizableToolProtocol: ChatToolProtocol {
    var authorizationMetadata: MCPToolAuthorizationMetadata { get }
    var isAvailableForAdvertisement: Bool { get }
    func validateForAuthorization(arguments: String) throws
    func validateBeforeExecution(arguments: String, approvedByUser: Bool) throws
    func executeAuthorized(arguments: String, approvedByUser: Bool) async throws -> ToolExecutionResult
}

nonisolated struct MCPToolAuthorizationMetadata: Equatable, Sendable {
    let toolId: String
    let displayName: String
    let serverName: String
    let toolDescription: String?
    let permissionKey: String
    let permission: MCPToolPermission

    func withPermission(_ permission: MCPToolPermission) -> MCPToolAuthorizationMetadata {
        MCPToolAuthorizationMetadata(
            toolId: toolId,
            displayName: displayName,
            serverName: serverName,
            toolDescription: toolDescription,
            permissionKey: permissionKey,
            permission: permission
        )
    }
}

nonisolated struct MCPToolAuthorizationRequest: Equatable, Identifiable, Sendable {
    let id: UUID
    let toolCallId: String
    let toolName: String
    let arguments: String
    let metadata: MCPToolAuthorizationMetadata

    var formattedArguments: String {
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ),
              let text = String(data: formatted, encoding: .utf8) else {
            return MCPDisplayText.escapedForCodeDisplay(arguments)
        }
        return MCPDisplayText.escapedForCodeDisplay(text)
    }

    var displayToolName: String {
        MCPDisplayText.sanitize(
            toolName,
            fallback: String(localized: "External MCP tool"),
            maximumLength: 160
        )
    }
}

nonisolated enum MCPToolAuthorizationDecision: Equatable, Sendable {
    case allowOnce
    case denyOnce
    case alwaysAllow
    case alwaysDeny

    var allowsExecution: Bool {
        switch self {
        case .allowOnce, .alwaysAllow: true
        case .denyOnce, .alwaysDeny: false
        }
    }

    var isPermanent: Bool {
        switch self {
        case .alwaysAllow, .alwaysDeny: true
        case .allowOnce, .denyOnce: false
        }
    }
}

nonisolated struct MCPToolAuthorizationBatch: Equatable, Identifiable, Sendable {
    let id: UUID
    let requests: [MCPToolAuthorizationRequest]
    var decisions: [UUID: MCPToolAuthorizationDecision]

    var isComplete: Bool {
        requests.allSatisfy { decisions[$0.id] != nil }
    }
}

@MainActor
protocol MCPToolAuthorizing: Sendable {
    func authorize(
        _ requests: [MCPToolAuthorizationRequest]
    ) async throws -> [UUID: MCPToolAuthorizationDecision]
}
