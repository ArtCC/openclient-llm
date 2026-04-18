//
//  GetCurrentDatetimeTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 17/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct GetCurrentDatetimeTool: ChatToolProtocol {
    // MARK: - Properties

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: "get_current_datetime",
                description: "Returns the current date, time, weekday, and timezone on the user's device. " +
                    "Use this when the user asks about the current date or time, or when you need " +
                    "the current date to answer a time-sensitive question accurately.",
                parameters: ToolParameters(
                    type: "object",
                    properties: [:],
                    required: []
                )
            )
        )
    }

    // MARK: - Execute

    func execute(arguments: String) async throws -> ToolExecutionResult {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current

        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let datePart = formatter.string(from: now)

        formatter.dateFormat = "HH:mm:ss"
        let timePart = formatter.string(from: now)

        let timeZoneName = TimeZone.current.identifier
        let result = "\(datePart) at \(timePart) (\(timeZoneName))"
        return ToolExecutionResult(text: result)
    }
}
