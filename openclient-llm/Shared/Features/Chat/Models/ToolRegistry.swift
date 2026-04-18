//
//  ToolRegistry.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ToolRegistry: Sendable {
    // MARK: - Properties

    private let tools: [String: any ChatToolProtocol]

    var definitions: [ToolDefinition] {
        tools.values.map { $0.definition }
    }

    // MARK: - Init

    init(tools: [any ChatToolProtocol]) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.definition.function.name, $0) })
    }

    // MARK: - Public

    func execute(toolName: String, arguments: String) async throws -> ToolExecutionResult {
        guard let tool = tools[toolName] else {
            return ToolExecutionResult(text: "Unknown tool: \(toolName)")
        }
        return try await tool.execute(arguments: arguments)
    }

    // MARK: - Factory

    static func `default`(
        webSearchEnabled: Bool = true,
        webSearchUseCase: WebSearchUseCaseProtocol = WebSearchUseCase(),
        memoryManager: MemoryManagerProtocol = MemoryManager()
    ) -> ToolRegistry {
        var tools: [any ChatToolProtocol] = [
            GetCurrentDatetimeTool(),
            SaveMemoryTool(memoryManager: memoryManager),
            DeleteMemoryTool(memoryManager: memoryManager)
        ]
        if webSearchEnabled {
            tools.append(WebSearchTool(webSearchUseCase: webSearchUseCase))
        }
        return ToolRegistry(tools: tools)
    }
}
