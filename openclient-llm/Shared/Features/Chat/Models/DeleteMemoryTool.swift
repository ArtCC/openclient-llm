//
//  DeleteMemoryTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 17/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct DeleteMemoryTool: ChatToolProtocol {
    // MARK: - Properties

    private let memoryManager: MemoryManagerProtocol

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: "delete_memory",
                description: "Delete a specific memory item that is no longer accurate or relevant. " +
                    "Use this when the user asks to forget something, corrects outdated information, " +
                    "or explicitly requests a memory to be removed. Match by the content of the item.",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "content": ToolParameterProperty(
                            type: "string",
                            description: "The exact or approximate content of the memory item to delete. " +
                                "The item whose content most closely matches this value will be removed."
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
              let query = json["content"]?.trimmingCharacters(in: .whitespaces),
              !query.isEmpty else {
            return ToolExecutionResult(text: "No content provided to identify the memory item to delete.")
        }

        let items = memoryManager.getItems()
        let queryLowercased = query.lowercased()

        // Find best match: exact first, then substring
        let match = items.first { $0.content.lowercased() == queryLowercased }
            ?? items.first { $0.content.lowercased().contains(queryLowercased) }

        guard let item = match else {
            return ToolExecutionResult(text: "No memory item found matching: \(query)")
        }

        memoryManager.delete(id: item.id)

        NotificationCenter.default.post(
            name: MemoryManager.memoryDidChangeExternallyNotification,
            object: nil
        )

        return ToolExecutionResult(text: String(localized: "Deleted from memory: \(item.content)"))
    }
}
