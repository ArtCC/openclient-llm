//
//  ChatTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ToolExecutionResult

nonisolated struct ToolExecutionResult: Sendable {
    // MARK: - Properties

    let text: String

    /// Non-nil when the tool performed a web search — used to display sources in the UI.
    let searchResults: [LiteLLMSearchResult]?

    // MARK: - Init

    init(text: String, searchResults: [LiteLLMSearchResult]? = nil) {
        self.text = text
        self.searchResults = searchResults
    }
}

// MARK: - ChatToolProtocol

protocol ChatToolProtocol: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: String) async throws -> ToolExecutionResult
}
