//
//  ChatViewModel+WebSearch.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Web Search helpers

extension ChatViewModel {
    func toggleWebSearch() {
        guard case .loaded(var loadedState) = state else { return }
        let newValue = !loadedState.isWebSearchEnabled
        settingsManager.setIsWebSearchEnabled(newValue)
        loadedState.isWebSearchEnabled = newValue
        state = .loaded(loadedState)
        LogManager.debug("webSearch toggled: \(newValue)")
    }

    func buildWebSearchContext(results: [LiteLLMSearchResult]) -> String {
        guard !results.isEmpty else { return "" }
        let topResults = results.prefix(5)
        var context = String(localized: "Based on the following web search results:")
        context += "\n\n"
        for (index, result) in topResults.enumerated() {
            context += "\(index + 1). [\(result.title)](\(result.url))\n"
            context += "   \(result.snippet)\n\n"
        }
        let citationGuide = String(
            localized: "Use these sources to answer the user's question. Cite sources using [Source Title](URL) format."
        )
        context += citationGuide
        return context
    }

    func fetchSearchResults(for query: String) async -> [LiteLLMSearchResult] {
        guard case .loaded(var loadedState) = state else { return [] }
        loadedState.isSearchingWeb = true
        state = .loaded(loadedState)
        let results: [LiteLLMSearchResult]
        do {
            results = try await webSearchUseCase.execute(query: query)
        } catch {
            LogManager.error("WebSearch failed (proceeding without results): \(error)")
            results = []
        }
        guard case .loaded(var doneState) = state else { return results }
        doneState.isSearchingWeb = false
        state = .loaded(doneState)
        return results
    }
}
