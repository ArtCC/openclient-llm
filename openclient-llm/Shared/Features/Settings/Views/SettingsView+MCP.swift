//
//  SettingsView+MCP.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension SettingsView {
    func mcpSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            if loadedState.isLoadingMCPTools {
                loadingRow
            }
            mcpStatusRow(loadedState)
            mcpRefreshButton(loadedState)
            mcpServerRows(loadedState)
            if let error = loadedState.mcpToolsError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(String(localized: "MCP Tools"))
        } footer: {
            mcpSectionFooter(loadedState)
        }
    }

    var loadingRow: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "Loading…"))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func mcpServerRows(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        if !loadedState.availableMCPServers.isEmpty {
            ForEach(loadedState.availableMCPServers) { server in
                let serverTools = loadedState.toolsForServer(server.serverName)
                let enabled = serverTools.filter {
                    loadedState.enabledMCPToolIds.contains($0.prefixedName)
                }.count
                Button {
                    mcpServerSheet = server
                } label: {
                    serverRowLabel(server: server, enabled: enabled, total: serverTools.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func mcpSectionFooter(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        if loadedState.availableMCPServers.isEmpty {
            Text(String(localized: """
                MCP tools are configured in your LiteLLM server. \
                Fetch to see what's available and toggle them on or off.
                """))
        } else {
            let enabled = loadedState.enabledMCPToolIds.count
            let total = loadedState.availableMCPTools.count
            Text(String(localized: """
                \(enabled) of \(total) MCP tool(s) enabled. \
                Tools can also be managed from the chat input bar.
                """))
        }
    }

    func mcpToolSheet(
        server: MCPServerInfo,
        loadedState: SettingsViewModel.LoadedState
    ) -> some View {
        NavigationStack {
            let tools = loadedState.toolsForServer(server.serverName)
            serverToolListView(server: server, tools: tools, loadedState: loadedState)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done")) { mcpServerSheet = nil }
                    }
                }
        }
    }

    func serverRowLabel(server: MCPServerInfo, enabled: Int, total: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(server.serverName)
                    .font(.headline)
                if let description = server.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(enabled)/\(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func mcpStatusRow(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        if loadedState.availableMCPServers.isEmpty
            && !loadedState.isLoadingMCPTools
            && loadedState.mcpToolsError == nil {
            Label(
                String(localized: "No MCP tools loaded. Tap \"Load Available Tools\" to fetch them from your server."),
                systemImage: "antenna.radiowaves.left.and.right"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
            Label(
                String(localized: "\(loadedState.availableMCPServers.count) server(s) available"),
                systemImage: "antenna.radiowaves.left.and.right.circle"
            )
        }
    }

    @ViewBuilder
    func mcpRefreshButton(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Button {
            viewModel.send(.fetchMCPToolsTapped)
        } label: {
            HStack {
                if loadedState.isLoadingMCPTools {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Loading…"))
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        loadedState.availableMCPServers.isEmpty
                            ? String(localized: "Load Available Tools")
                            : String(localized: "Refresh Tools"),
                        systemImage: "arrow.clockwise"
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(loadedState.isLoadingMCPTools)
    }

    func serverToolListView(
        server: MCPServerInfo,
        tools: [MCPToolInfo],
        loadedState: SettingsViewModel.LoadedState
    ) -> some View {
        let allEnabled = tools.allSatisfy {
            loadedState.enabledMCPToolIds.contains($0.prefixedName)
        }
        return List {
            Section {
                Toggle(isOn: Binding(
                    get: { allEnabled },
                    set: { enable in
                        for tool in tools {
                            viewModel.send(.mcpToolToggled(
                                toolId: tool.prefixedName, enabled: enable
                            ))
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Enable All Tools"))
                            .font(.headline)
                        Text(String(localized: "\(tools.count) tool(s) available"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                ForEach(tools) { tool in
                    mcpToolToggleRow(tool, loadedState: loadedState)
                }
            }
        }
        .navigationTitle(server.serverName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    func mcpToolToggleRow(
        _ tool: MCPToolInfo,
        loadedState: SettingsViewModel.LoadedState
    ) -> some View {
        let isEnabled = loadedState.enabledMCPToolIds.contains(tool.prefixedName)
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { enabled in
                viewModel.send(.mcpToolToggled(
                    toolId: tool.prefixedName, enabled: enabled
                ))
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                if let description = tool.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

extension SettingsViewModel.LoadedState {
    func toolsForServer(_ serverName: String) -> [MCPToolInfo] {
        availableMCPTools.filter { $0.serverName == serverName }
    }
}
