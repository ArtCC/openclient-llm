//
//  ToolCallResult.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ToolCallResult: Sendable {
    let toolCallId: String
    let toolName: String
    let executionResult: ToolExecutionResult
}
