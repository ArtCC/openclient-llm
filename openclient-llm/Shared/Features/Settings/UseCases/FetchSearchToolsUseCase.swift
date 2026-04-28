//
//  FetchSearchToolsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol FetchSearchToolsUseCaseProtocol: Sendable {
    func execute() async throws -> [SearchToolItem]
}

struct FetchSearchToolsUseCase: FetchSearchToolsUseCaseProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Execute

    func execute() async throws -> [SearchToolItem] {
        LogManager.network("FetchSearchTools → GET /v1/search/tools")
        let response = try await apiClient.fetchSearchTools()
        LogManager.success("FetchSearchTools tools=\(response.data.count)")
        return response.data
    }
}
