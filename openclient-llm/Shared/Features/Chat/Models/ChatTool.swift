//
//  ChatTool.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ChatToolProtocol: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: String) async throws -> String
}
