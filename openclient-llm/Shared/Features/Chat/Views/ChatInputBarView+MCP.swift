//
//  ChatInputBarView+MCP.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import TipKit

extension ChatInputBarView {
    var mcpButton: some View {
        let modelSupportsTools = loadedState.selectedModel?.capabilities.contains(.functionCalling) == true
        return Button {
            AppTips.mcpServers.invalidate(reason: .actionPerformed)
            onMCPButtonTapped()
        } label: {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(mcpColor(
                    supported: hasAvailableMCPTool && modelSupportsTools,
                    hasEnabled: hasEnabledMCPTool
                ))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popoverTip(canShowMCPTip ? AppTips.mcpServers : nil, arrowEdge: .bottom)
        .accessibilityLabel(
            hasAvailableMCPTool && modelSupportsTools
                ? String(localized: "MCP Servers")
                : String(localized: "MCP Servers Unavailable")
        )
        .animation(.easeInOut(duration: 0.2), value: loadedState.enabledMCPToolIds)
    }
}

extension ChatInputBarView {
    var availableMCPToolIds: Set<String> {
        Set(loadedState.availableMCPTools.compactMap { tool in
            guard tool.isInputSchemaSupported,
                  !loadedState.failedMCPServerIds.contains(tool.serverId) else { return nil }
            return tool.id
        })
    }

    var hasAvailableMCPTool: Bool { !availableMCPToolIds.isEmpty }

    var hasEnabledMCPTool: Bool {
        !loadedState.enabledMCPToolIds.isDisjoint(with: availableMCPToolIds)
    }

    var canShowMCPTip: Bool {
        !loadedState.isStreaming
            && !loadedState.isRecording
            && !loadedState.isTranscribing
            && !loadedState.isSearchingWeb
            && hasAvailableMCPTool
            && loadedState.selectedModel?.capabilities.contains(.functionCalling) == true
    }

    func mcpColor(supported: Bool, hasEnabled: Bool) -> Color {
        guard supported else { return .red }
        return hasEnabled ? Color.appAccent : .secondary
    }
}
