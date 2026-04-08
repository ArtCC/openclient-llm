//
//  WebSearchTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct WebSearchTool: ChatToolProtocol {
    // MARK: - Properties

    private let webSearchUseCase: WebSearchUseCaseProtocol

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: "web_search",
                description: "Search the web for current information, recent news, real-time data, " +
                    "or facts that may have changed after your training cutoff.",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "query": ToolParameterProperty(
                            type: "string",
                            description: "The search query to look up on the web."
                        )
                    ],
                    required: ["query"]
                )
            )
        )
    }

    // MARK: - Init

    init(webSearchUseCase: WebSearchUseCaseProtocol = WebSearchUseCase()) {
        self.webSearchUseCase = webSearchUseCase
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONDecoder().decode([String: String].self, from: data),
              let query = json["query"], !query.isEmpty else {
            return ToolExecutionResult(
                text: "No search query was provided. Please answer the user's question directly " +
                    "using your existing knowledge without performing a web search."
            )
        }

        let results = try await webSearchUseCase.execute(query: query)

        guard !results.isEmpty else {
            return ToolExecutionResult(
                text: String(localized: "No results found for: \(query)")
            )
        }

        var output = ""
        for (index, result) in results.prefix(5).enumerated() {
            output += "\(index + 1). \(result.title)\n"
            output += "   URL: \(result.url)\n"
            output += "   \(result.snippet)\n\n"
        }
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        output += "\n\n" + String(
            localized: "Use these sources to answer the user's question. Cite sources using [Source Title](URL) format."
        )
        return ToolExecutionResult(text: output, searchResults: results)
    }
}
