//
//  ChatRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ChatRepositoryProtocol: Sendable {
    func sendMessage(messages: [ChatMessage], model: String) async throws -> String
    func streamMessage(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error>
}

struct ChatRepository: ChatRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func sendMessage(messages: [ChatMessage], model: String) async throws -> String {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages.map { ChatCompletionMessage(role: $0.role.rawValue, content: $0.content) },
            stream: false
        )

        let response: ChatCompletionResponse = try await apiClient.request(
            endpoint: "chat/completions",
            method: .post,
            body: request
        )

        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }

        return content
    }

    func streamMessage(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error> {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages.map { ChatCompletionMessage(role: $0.role.rawValue, content: $0.content) },
            stream: true
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let dataStream = apiClient.streamRequest(endpoint: "chat/completions", body: request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in dataStream {
                        guard !Task.isCancelled else { break }

                        let chunk = try decoder.decode(ChatCompletionStreamResponse.self, from: data)
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
