//
//  MCPToolPermission.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

nonisolated enum MCPToolPermission: String, CaseIterable, Codable, Hashable, Sendable {
    case alwaysAllow
    case ask
    case deny
}

extension SettingsManagerProtocol {
    func getMCPToolPermission(for key: String) -> MCPToolPermission {
        guard let rawValue = getMCPToolPermissionRawValue(for: key) else { return .ask }
        return MCPToolPermission(rawValue: rawValue) ?? .ask
    }

    func setMCPToolPermission(_ permission: MCPToolPermission, for key: String) {
        setMCPToolPermissionRawValue(permission.rawValue, for: key)
    }

    func setMCPToolPermission(_ permission: MCPToolPermission, for keys: [String]) {
        setMCPToolPermissionRawValues(permission.rawValue, for: keys)
    }
}

extension MCPToolInfo {
    nonisolated func permissionKey(serverBaseURL: String, authorizationScope: String) -> String {
        let schemaData = rawInputSchemaData ?? Data("none".utf8)
        let normalizedURL = Self.normalizedServerURL(serverBaseURL)
        var descriptionData = Data([description == nil ? 0 : 1])
        if let description { descriptionData.append(Data(description.utf8)) }
        let components = [
            Data(normalizedURL.utf8),
            Data(authorizationScope.utf8),
            Data(serverId.utf8),
            Data(name.utf8),
            descriptionData,
            schemaData
        ]
        let payload = Data(components.map { $0.base64EncodedString() }.joined(separator: "\u{0}").utf8)
        return SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func normalizedServerURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        let usesDefaultPort = (components.scheme == "https" && components.port == 443)
            || (components.scheme == "http" && components.port == 80)
        if usesDefaultPort {
            components.port = nil
        }
        if components.percentEncodedPath == "/" {
            components.percentEncodedPath = ""
        } else {
            while components.percentEncodedPath.hasSuffix("/") {
                components.percentEncodedPath.removeLast()
            }
        }
        return components.string ?? trimmed
    }
}
