//
//  MCPServerToolsEmptyView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MCPServerToolsEmptyView: View {
    let didFail: Bool
    let onRetry: @MainActor @Sendable () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                didFail
                    ? String(localized: "Tools Could Not Be Loaded")
                    : String(localized: "No Tools Available"),
                systemImage: didFail ? "exclamationmark.triangle" : "wrench.and.screwdriver"
            )
        } description: {
            Text(didFail
                ? String(localized: "Refresh to try loading this MCP server again.")
                : String(localized: "This MCP server currently exposes no available tools."))
        } actions: {
            if didFail {
                Button(String(localized: "Retry"), action: onRetry)
            }
        }
    }
}

#Preview {
    MCPServerToolsEmptyView(didFail: true, onRetry: {})
}
