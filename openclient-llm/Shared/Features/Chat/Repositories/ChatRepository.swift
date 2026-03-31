//
//  ChatRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
import PDFKit

protocol ChatRepositoryProtocol: Sendable {
    func sendMessage(messages: [ChatMessage], model: String, parameters: ModelParameters) async throws -> (String, TokenUsage?)
    func streamMessage(messages: [ChatMessage], model: String, parameters: ModelParameters) -> AsyncThrowingStream<StreamChunk, Error>
}

enum StreamChunk: Sendable {
    case token(String)
    case usage(TokenUsage)
}

struct ChatRepository: ChatRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func sendMessage(messages: [ChatMessage], model: String, parameters: ModelParameters) async throws -> (String, TokenUsage?) {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages.map { buildCompletionMessage($0) },
            stream: false,
            temperature: parameters.temperature,
            maxTokens: parameters.maxTokens,
            topP: parameters.topP,
            streamOptions: nil
        )

        let response: ChatCompletionResponse = try await apiClient.request(
            endpoint: "chat/completions",
            method: .post,
            body: request
        )

        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }

        let tokenUsage = response.usage.map {
            TokenUsage(
                promptTokens: $0.promptTokens ?? 0,
                completionTokens: $0.completionTokens ?? 0,
                totalTokens: $0.totalTokens ?? 0
            )
        }

        return (content, tokenUsage)
    }

    func streamMessage(messages: [ChatMessage], model: String, parameters: ModelParameters) -> AsyncThrowingStream<StreamChunk, Error> {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages.map { buildCompletionMessage($0) },
            stream: true,
            temperature: parameters.temperature,
            maxTokens: parameters.maxTokens,
            topP: parameters.topP,
            streamOptions: ChatCompletionRequest.StreamOptions(includeUsage: true)
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
                            continuation.yield(.token(content))
                        }
                        if let usage = chunk.usage {
                            let tokenUsage = TokenUsage(
                                promptTokens: usage.promptTokens ?? 0,
                                completionTokens: usage.completionTokens ?? 0,
                                totalTokens: usage.totalTokens ?? 0
                            )
                            continuation.yield(.usage(tokenUsage))
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

// MARK: - Private

private extension ChatRepository {
    func buildCompletionMessage(_ message: ChatMessage) -> ChatCompletionMessage {
        if message.attachments.isEmpty {
            return ChatCompletionMessage(
                role: message.role.rawValue,
                content: .text(message.content)
            )
        }

        var parts: [ContentPart] = []

        if !message.content.isEmpty {
            parts.append(.text(message.content))
        }

        for attachment in message.attachments {
            switch attachment.type {
            case .image:
                let base64 = attachment.data.base64EncodedString()
                let mimeType = imageMimeType(for: attachment.fileName)
                parts.append(.imageBase64(base64, mimeType: mimeType))
            case .pdf:
                let pdfText = extractPDFText(from: attachment.data)
                if !pdfText.isEmpty {
                    parts.append(.text("[Document: \(attachment.fileName)]\n\(pdfText)"))
                }
            }
        }

        return ChatCompletionMessage(
            role: message.role.rawValue,
            content: .multimodal(parts)
        )
    }

    func imageMimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/jpeg"
        }
    }

    func extractPDFText(from data: Data) -> String {
        guard let pdfDocument = PDFDocument(data: data) else { return "" }
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText
    }
}
