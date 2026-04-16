//
//  SaveMemoryTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct SaveMemoryTool: ChatToolProtocol {
    // MARK: - Properties

    private let memoryManager: MemoryManagerProtocol

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: "save_memory",
                description: "Save a piece of information to the user's persistent memory so it can " +
                    "be recalled in future conversations. Use this when the user shares important " +
                    "personal details, preferences, or context that should be remembered long-term.",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "content": ToolParameterProperty(
                            type: "string",
                            description: "The information to remember. " +
                                "Keep it concise and specific (e.g. 'User prefers dark mode', " +
                                "'User's favourite language is Swift')."
                        )
                    ],
                    required: ["content"]
                )
            )
        )
    }

    // MARK: - Init

    init(memoryManager: MemoryManagerProtocol = MemoryManager()) {
        self.memoryManager = memoryManager
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONDecoder().decode([String: String].self, from: data),
              let content = json["content"], !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ToolExecutionResult(text: "No content provided to save to memory.")
        }

        let trimmed = content.trimmingCharacters(in: .whitespaces)
        let item = MemoryItem(content: trimmed, source: .model)
        memoryManager.add(item)

        NotificationCenter.default.post(
            name: MemoryManager.memoryDidChangeExternallyNotification,
            object: nil
        )

        return ToolExecutionResult(text: String(localized: "Saved to memory: \(trimmed)"))
    }
}
