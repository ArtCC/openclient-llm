//
//  ChatViewModel+MCP.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ChatViewModel {
    func makeLoadedState(
        models: [LLMModel],
        mcpResult: MCPDiscoveryResult? = nil,
        pending: Conversation?,
        errorMessage: String? = nil
    ) -> LoadedState {
        let mcpTools = mcpResult?.tools ?? []
        let mcpServers = mcpResult?.servers ?? []
        let chatModels = models.filter {
            [.chat, .completion, .unknown, .imageGeneration].contains($0.mode)
        }
        let savedModelID = getChatPreferencesUseCase.getSelectedModelId()
        let selectedModel = chatModels.first(where: { $0.id == pending?.modelId })
            ?? chatModels.first(where: { $0.id == savedModelID })
            ?? chatModels.first
        let audioModelIDs = resolveAudioModelIdsUseCase.execute(from: models)
        var loadedState = LoadedState(
            conversation: pending,
            messages: pending?.messages ?? [],
            selectedModel: selectedModel,
            availableModels: chatModels,
            conversationStarters: (pending?.messages ?? []).isEmpty
                ? getConversationStartersUseCase.execute(count: 4)
                : [],
            errorMessage: errorMessage,
            systemPrompt: pending?.systemPrompt ?? "",
            modelParameters: pending?.modelParameters ?? .default,
            contextWindowTokens: pending?.contextWindowTokens,
            showTokenUsage: getChatPreferencesUseCase.getShowTokenUsage(),
            ttsModelId: audioModelIDs.ttsModelId,
            transcriptionModelId: audioModelIDs.transcriptionModelId,
            isWebSearchEnabled: getChatPreferencesUseCase.getIsWebSearchEnabled(),
            isWebSearchToolConfigured: !getChatPreferencesUseCase.getWebSearchToolName().isEmpty,
            isMCPSupported: !mcpTools.isEmpty,
            availableMCPTools: mcpTools,
            availableMCPServers: mcpServers,
            enabledMCPToolIds: enabledMCPToolIds(
                savedIds: settingsManager.getEnabledMCPToolIds(),
                tools: mcpTools
            )
        )
        refreshContextUsage(in: &loadedState)
        return loadedState
    }
    func handleMCPEvent(_ event: Event) {
        switch event {
        case .mcpButtonTapped:
            refreshMCPTools()
        case .mcpToolsRefreshed:
            refreshMCPTools()
        case .mcpToolToggled(let toolId, let enabled):
            toggleMCPTool(toolId: toolId, enabled: enabled)
        default:
            break
        }
    }

    func refreshMCPTools() {
        guard case .loaded(let loadedState) = state, !loadedState.isLoadingMCPTools else { return }
        var update = loadedState
        update.isLoadingMCPTools = true
        state = .loaded(update)

        Task { [weak self] in
            guard let self else { return }
            let result = await fetchMCPToolsUseCase.execute()
            guard case .loaded(var currentState) = state else { return }
            if result.errorMessage != nil && result.servers.isEmpty {
                currentState.isLoadingMCPTools = false
                currentState.errorMessage = result.errorMessage
                state = .loaded(currentState)
                return
            }
            let enabledIds = settingsManager.getEnabledMCPToolIds()
            let retainedTools = currentState.availableMCPTools.filter {
                result.failedServerIds.contains($0.serverId)
            }
            let discoveredTools = result.tools + retainedTools
            currentState.isMCPSupported = !discoveredTools.isEmpty
            currentState.availableMCPTools = discoveredTools
            currentState.availableMCPServers = result.servers
            let normalizedEnabledIds = enabledMCPToolIds(
                savedIds: enabledIds,
                tools: discoveredTools
            )
            settingsManager.setEnabledMCPToolIds(Array(normalizedEnabledIds))
            currentState.enabledMCPToolIds = normalizedEnabledIds
            currentState.isLoadingMCPTools = false
            refreshContextUsage(in: &currentState)
            state = .loaded(currentState)
        }
    }

    func toggleMCPTool(toolId: String, enabled: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        cancelCompaction()
        if enabled {
            loadedState.enabledMCPToolIds.insert(toolId)
        } else {
            loadedState.enabledMCPToolIds.remove(toolId)
        }
        settingsManager.setEnabledMCPToolIds(Array(loadedState.enabledMCPToolIds))
        refreshContextUsage(in: &loadedState)
        state = .loaded(loadedState)
    }

    func enabledMCPToolIds(savedIds: [String], tools: [MCPToolInfo]) -> Set<String> {
        let currentIds = Set(tools.map(\.id))
        let legacyIds = Dictionary(uniqueKeysWithValues: tools.map { ($0.prefixedName, $0.id) })
        return Set(savedIds.compactMap { savedId in
            if currentIds.contains(savedId) { return savedId }
            return legacyIds[savedId]
        })
    }
}
