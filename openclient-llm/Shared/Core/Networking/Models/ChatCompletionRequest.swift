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

nonisolated struct ChatCompletionMessage: Encodable, Sendable {
    // MARK: - Properties

    let role: String
    let content: Content

    enum Content: Sendable {
        case text(String)
        case multimodal([ContentPart])
    }

    // MARK: - Encodable

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .multimodal(let parts):
            try container.encode(parts, forKey: .content)
        }
    }
}

// MARK: - ContentPart

nonisolated struct ContentPart: Encodable, Sendable {
    // MARK: - Properties

    let type: String
    let text: String?
    let imageUrl: ImageURL?

    struct ImageURL: Encodable, Sendable {
        let url: String
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    // MARK: - Factory

    static func text(_ text: String) -> ContentPart {
        ContentPart(type: "text", text: text, imageUrl: nil)
    }

    static func imageBase64(_ base64: String, mimeType: String) -> ContentPart {
        ContentPart(
            type: "image_url",
            text: nil,
            imageUrl: ImageURL(url: "data:\(mimeType);base64,\(base64)")
        )
    }
}
