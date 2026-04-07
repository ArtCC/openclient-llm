//
//  ChatCompletionRequest.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ChatStreamOptions

nonisolated struct ChatStreamOptions: Encodable, Sendable {
    let includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

// MARK: - WebSearchOptions

/// Options passed to LiteLLM's `web_search_options` field.
/// Supported by models with native web search: OpenAI search models, xAI Grok-3,
/// Anthropic Claude 3.5+/3.7, Gemini 2.0+.
nonisolated struct WebSearchOptions: Encodable, Sendable {
    /// `"low"`, `"medium"` (default), or `"high"`.
    let searchContextSize: String

    init(searchContextSize: String = "medium") {
        self.searchContextSize = searchContextSize
    }

    enum CodingKeys: String, CodingKey {
        case searchContextSize = "search_context_size"
    }
}

// MARK: - ChatCompletionRequest

nonisolated struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [ChatCompletionMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let streamOptions: ChatStreamOptions?
    let modalities: [String]?
    let tools: [ToolDefinition]?
    let toolChoice: String?
    let webSearchOptions: WebSearchOptions?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case streamOptions = "stream_options"
        case modalities
        case tools
        case toolChoice = "tool_choice"
        case webSearchOptions = "web_search_options"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(streamOptions, forKey: .streamOptions)
        try container.encodeIfPresent(modalities, forKey: .modalities)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(webSearchOptions, forKey: .webSearchOptions)
    }
}

nonisolated struct ChatCompletionMessage: Encodable, Sendable {
    // MARK: - Properties

    let role: String
    let content: Content
    let toolCallId: String?
    let toolCalls: [ToolCall]?

    enum Content: Sendable {
        case text(String)
        case multimodal([ContentPart])
        case none
    }

    // MARK: - Init

    init(role: String, content: Content, toolCallId: String? = nil, toolCalls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    // MARK: - Encodable

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .multimodal(let parts):
            try container.encode(parts, forKey: .content)
        case .none:
            try container.encodeNil(forKey: .content)
        }
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
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

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
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
