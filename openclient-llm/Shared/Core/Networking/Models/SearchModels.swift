//
//  SearchModels.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct LiteLLMSearchRequest: Codable, Sendable {
    let query: String
    let maxResults: Int?
    let maxTokensPerPage: Int?
    let country: String?
    let searchDomainFilter: [String]?
}

nonisolated struct LiteLLMSearchResponse: Codable, Sendable {
    let object: String
    let results: [LiteLLMSearchResult]
}

nonisolated struct LiteLLMSearchResult: Codable, Equatable, Sendable {
    let title: String
    let url: String
    let snippet: String
    let date: String?
}
