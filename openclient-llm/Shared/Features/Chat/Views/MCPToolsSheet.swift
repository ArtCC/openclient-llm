//
//  MCPToolsSheet.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MCPToolsSheet: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Group {
            if case .loaded(let loadedState) = viewModel.state {
                loadedContent(loadedState)
            }
        }
    }
}

private extension MCPToolsSheet {
    func loadedContent(_ loadedState: ChatViewModel.LoadedState) -> some View {
        NavigationStack {
            Group {
                if loadedState.isLoadingMCPTools {
                    loadingContent
                } else if loadedState.availableMCPServers.isEmpty {
                    emptyContent
                } else {
                    serverListView(loadedState)
                }
            }
            .navigationTitle(String(localized: "MCP Servers"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { doneToolbar }
            .toolbar { refreshToolbar(loadedState: loadedState) }
        }
    }

    var loadingContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.secondary)
            Text(String(localized: "Loading tools..."))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    var emptyContent: some View {
        VStack {
            Spacer()
            Label(
                String(localized: "No MCP servers configured. Add them in your LiteLLM server's config.yaml."),
                systemImage: "server.rack"
            )
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    func serverListView(_ loadedState: ChatViewModel.LoadedState) -> some View {
        List {
            Section(String(localized: "Available Servers")) {
                ForEach(loadedState.availableMCPServers) { server in
                    let serverTools = loadedState.toolsForServer(server.serverId)
                    NavigationLink {
                        serverDetailView(
                            server: server,
                            tools: serverTools,
                            loadedState: loadedState
                        )
                    } label: {
                        serverRow(server: server, tools: serverTools, loadedState: loadedState)
                    }
                }
            }
        }
    }

    func serverRow(
        server: MCPServerInfo,
        tools: [MCPToolInfo],
        loadedState: ChatViewModel.LoadedState
    ) -> some View {
        let enabled = tools.filter { loadedState.enabledMCPToolIds.contains($0.id) }.count
        return HStack {
            Image(systemName: enabled > 0 ? "server.rack" : "server.rack")
                .foregroundStyle(enabled > 0 ? Color.appAccent : .secondary)
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
            Text(String(localized: "\(enabled)/\(tools.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func serverDetailView(
        server: MCPServerInfo,
        tools: [MCPToolInfo],
        loadedState: ChatViewModel.LoadedState
    ) -> some View {
        let allEnabled = tools.allSatisfy { loadedState.enabledMCPToolIds.contains($0.id) }
        let serverId = server.serverName
        return List {
            Section {
                Toggle(isOn: Binding(
                    get: { allEnabled },
                    set: { enable in
                        for tool in tools {
                             viewModel.send(.mcpToolToggled(
                                 toolId: tool.id,
                                enabled: enable
                            ))
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Enable All Tools"))
                            .font(.headline)
                        let count = tools.count
                        Text(String(localized: "\(count) tool(s) available"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            Section {
                ForEach(tools) { tool in
                    mcpToolRow(tool, loadedState: loadedState)
                }
            }
        }
        .navigationTitle(serverId)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    func mcpToolRow(
        _ tool: MCPToolInfo,
        loadedState: ChatViewModel.LoadedState
    ) -> some View {
        let isEnabled = loadedState.enabledMCPToolIds.contains(tool.id)
        return Toggle(isOn: Binding(
            get: { isEnabled },
            set: { enabled in
                viewModel.send(.mcpToolToggled(toolId: tool.id, enabled: enabled))
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                if let description = tool.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    @ToolbarContentBuilder
    var doneToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "Done")) {
                isPresented = false
            }
        }
    }

    @ToolbarContentBuilder
    func refreshToolbar(loadedState: ChatViewModel.LoadedState?) -> some ToolbarContent {
        let isLoading = loadedState?.isLoadingMCPTools ?? false
        ToolbarItem(placement: .cancellationAction) {
            Button {
                viewModel.send(.mcpToolsRefreshed)
            } label: {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(isLoading)
            .accessibilityLabel(String(localized: "Refresh"))
        }
    }
}

// MARK: - Helpers

extension ChatViewModel.LoadedState {
    func toolsForServer(_ serverId: String) -> [MCPToolInfo] {
        availableMCPTools.filter { $0.serverId == serverId }
    }
}

#Preview {
    let servers = [
        MCPServerInfo(serverId: "gh", serverName: "github", description: "Manage repos, issues, PRs", allowedTools: nil)
    ]
    let tool1 = MCPToolInfo(name: "search_issues", description: "Search GitHub issues",
        serverId: "gh", serverName: "github", inputSchema: nil)
    let tool2 = MCPToolInfo(name: "create_pr", description: "Create a pull request",
        serverId: "gh", serverName: "github", inputSchema: nil)
    return MCPToolsSheet(
        viewModel: ChatViewModel(state: .loaded(ChatViewModel.LoadedState(
            isMCPSupported: true,
            availableMCPTools: [tool1, tool2],
            availableMCPServers: servers,
            enabledMCPToolIds: ["gh-search_issues"]
        ))),
        isPresented: .constant(true)
    )
}
