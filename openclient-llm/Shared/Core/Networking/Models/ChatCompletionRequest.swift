//
//  ChatCompletionRequest.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [ChatCompletionMessage]
    let stream: Bool
}

nonisolated struct ChatCompletionMessage: Codable, Sendable {
    let role: String
    let content: String
}
