//
//  WebSearchUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol WebSearchUseCaseProtocol: Sendable {
    func execute(query: String) async throws -> [LiteLLMSearchResult]
}

struct WebSearchUseCase: WebSearchUseCaseProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol
    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(
        apiClient: APIClientProtocol = APIClient(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.apiClient = apiClient
        self.settingsManager = settingsManager
    }

    // MARK: - Public

    func execute(query: String) async throws -> [LiteLLMSearchResult] {
        let toolName = settingsManager.getWebSearchToolName()
        let maxResults = settingsManager.getWebSearchMaxResults()
        let body = LiteLLMSearchRequest(
            query: query,
            maxResults: maxResults,
            maxTokensPerPage: nil,
            country: nil,
            searchDomainFilter: nil
        )
        LogManager.network("WebSearch query=\(query) tool=\(toolName) maxResults=\(maxResults)")
        let response = try await apiClient.searchRequest(toolName: toolName, body: body)
        LogManager.success("WebSearch results=\(response.results.count)")
        return response.results
    }
}
