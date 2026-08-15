//
//  ChatViewModel+StreamingLifecycle.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ChatViewModel {
    func cancelActiveStreaming(shouldPersist: Bool = true) {
        mcpAuthorizationCoordinator.cancelPending()
        streamTask?.cancel()
        streamTask = nil
        activeAssistantMessageId = nil
        streamingBackgroundUseCase.end()
        guard case .loaded(var loadedState) = state else { return }
        guard loadedState.isStreaming else { return }
        loadedState.isStreaming = false
        loadedState.isSearchingWeb = false
        loadedState.activeToolCallIds = []
        loadedState.activeToolNamesById = [:]
        refreshContextUsage(in: &loadedState)
        state = .loaded(loadedState)
        if shouldPersist {
            scheduleConversationPersistence()
        }
    }

    func stopStreaming() {
        LogManager.debug("stopStreaming requested")
        cancelActiveStreaming()
    }

    func beginStreamingBackground(for assistantMessageId: UUID) {
        streamingBackgroundUseCase.begin { [weak self] in
            LogManager.warning("Background time expired — saving partial response")
            guard let self, self.activeAssistantMessageId == assistantMessageId else { return }
            self.mcpAuthorizationCoordinator.cancelPending()
            self.streamTask?.cancel()
            self.streamTask = nil
            self.activeAssistantMessageId = nil
            guard case .loaded(var currentState) = self.state else { return }
            currentState.isStreaming = false
            currentState.isSearchingWeb = false
            currentState.activeToolCallIds = []
            currentState.activeToolNamesById = [:]
            self.refreshContextUsage(in: &currentState)
            self.state = .loaded(currentState)
            self.scheduleConversationPersistence()
            Task { await self.notifyStreamingCompletedUseCase.executeExpired() }
        }
    }
}
