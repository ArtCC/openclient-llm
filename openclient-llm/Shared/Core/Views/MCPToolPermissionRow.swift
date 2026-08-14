//
//  MCPToolPermissionRow.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MCPToolPermissionRow: View {
    let tool: MCPToolInfo
    let isEnabled: Bool
    let isAvailable: Bool
    let permission: MCPToolPermission
    let onEnabledChanged: @MainActor @Sendable (Bool) -> Void
    let onPermissionChanged: @MainActor @Sendable (MCPToolPermission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { enabled in onEnabledChanged(enabled) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                    if let description = tool.displayDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .disabled(!isAvailable)

            if isAvailable {
                LabeledContent(String(localized: "Permission")) {
                    Picker(
                        String(localized: "Permission"),
                        selection: Binding(
                            get: { permission },
                            set: { permission in onPermissionChanged(permission) }
                        )
                    ) {
                        ForEach(MCPToolPermission.allCases, id: \.self) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .font(.subheadline)
            } else {
                LabeledContent(String(localized: "Permission")) {
                    Label(String(localized: "Unavailable"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Label(impactText, systemImage: "network")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private extension MCPToolPermissionRow {
    var impactText: String {
        if !isAvailable {
            return String(localized: "This tool is unavailable until its server and input schema can be verified.")
        }
        if isEnabled, permission == .deny {
            return String(localized: "The model can request this external tool, but execution will be blocked.")
        }
        return String(localized: "This external tool may access, create, change, or delete data and may incur costs.")
    }
}

extension MCPToolPermission {
    var title: String {
        switch self {
        case .alwaysAllow: String(localized: "Always Allow")
        case .ask: String(localized: "Ask Every Time")
        case .deny: String(localized: "Deny")
        }
    }

    var systemImage: String {
        switch self {
        case .alwaysAllow: "checkmark.shield"
        case .ask: "questionmark.circle"
        case .deny: "nosign"
        }
    }
}

#Preview {
    List {
        MCPToolPermissionRow(
            tool: MCPToolInfo(
                name: "create_issue",
                description: "Create an issue in a repository",
                serverId: "github",
                serverName: "GitHub",
                inputSchema: nil
            ),
            isEnabled: true,
            isAvailable: true,
            permission: .ask,
            onEnabledChanged: { _ in },
            onPermissionChanged: { _ in }
        )
    }
}
