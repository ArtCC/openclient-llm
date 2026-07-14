//
//  CompactConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol CompactConversationUseCaseProtocol: Sendable {
    func execute(messages: [ChatMessage], configuration: CompactionConfiguration) async throws -> CompactedConversation?
}

struct CompactionConfiguration: Sendable {
    let existingSummary: String?
    let summaryCursorMessageId: UUID?
    let model: String
    let contextWindowTokens: Int?
    let maxOutputTokens: Int?
    let systemPrompt: String
    let tools: [ToolDefinition]
}

struct CompactedConversation: Sendable, Equatable {
    let summary: String
    let cursorMessageId: UUID
}

enum CompactConversationError: Error {
    case invalidSummaryResponse
    case sourceCannotFit
}

struct CompactConversationUseCase: CompactConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ChatRepositoryProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(
        repository: ChatRepositoryProtocol = ChatRepository(),
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository()
    ) {
        self.repository = repository
        self.attachmentRepository = attachmentRepository
    }

    // MARK: - Public

    func execute(
        messages: [ChatMessage],
        configuration: CompactionConfiguration
    ) async throws -> CompactedConversation? {
        guard let contextWindowTokens = configuration.contextWindowTokens, contextWindowTokens > 0 else { return nil }
        let builder = ContextWindowBuilder()
        let uncompactedMessages = messagesAfterCursor(
            messages,
            cursorMessageId: configuration.summaryCursorMessageId
        )
        let model = LLMModel(id: configuration.model, maxInputTokens: contextWindowTokens)
        let context = builder.build(
            messages: uncompactedMessages,
            systemPrompt: configuration.systemPrompt,
            summary: configuration.existingSummary,
            model: model,
            tools: configuration.tools
        )
        guard !context.excludedMessages.isEmpty else { return nil }
        let systemPrompt = summarySystemPrompt(existingSummary: configuration.existingSummary)
        let source = compactablePrefix(
            context.excludedMessages,
            systemPrompt: systemPrompt,
            model: model,
            builder: builder
        )
        guard let cursorMessageId = source.cursorMessageId else { return nil }
        if let oversizedSource = source.oversizedSource {
            let summary = try await summarizeOversizedSource(
                oversizedSource,
                existingSummary: configuration.existingSummary,
                configuration: configuration,
                model: model,
                builder: builder
            )
            return CompactedConversation(summary: summary, cursorMessageId: cursorMessageId)
        }
        let summary = try await repository.sendMessage(
            messages: [ChatMessage(role: .system, content: systemPrompt)] + source.messages,
            model: configuration.model,
            parameters: ModelParameters(maxTokens: summaryOutputTokens(configuration.maxOutputTokens))
        ).0.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? nil : CompactedConversation(summary: summary, cursorMessageId: cursorMessageId)
    }
}

// MARK: - Private

private extension CompactConversationUseCase {
    static let maximumSummaryTokens = 512

    struct CompactionSource {
        let messages: [ChatMessage]
        let cursorMessageId: UUID?
        let oversizedSource: String?
    }

    func messagesAfterCursor(_ messages: [ChatMessage], cursorMessageId: UUID?) -> [ChatMessage] {
        guard let cursorMessageId,
              let index = messages.firstIndex(where: { $0.id == cursorMessageId }) else { return messages }
        return Array(messages.dropFirst(index + 1))
    }

    func compactablePrefix(
        _ messages: [ChatMessage],
        systemPrompt: String,
        model: LLMModel,
        builder: ContextWindowBuilder
    ) -> CompactionSource {
        var selected: [ChatMessage] = []
        let groups = builder.turnGroups(messages)
        let limit = builder.usableInputTokens(for: model.maxInputTokens ?? 0)
        var estimated = builder.estimatedInputTokens(messages: [], systemPrompt: systemPrompt)
        for group in groups {
            let groupCost = builder.estimatedInputTokens(messages: group, systemPrompt: "")
            guard estimated + groupCost <= limit else { break }
            selected.append(contentsOf: group)
            estimated += groupCost
        }
        if let cursor = selected.last?.id {
            return CompactionSource(messages: selected, cursorMessageId: cursor, oversizedSource: nil)
        }
        guard let firstGroup = groups.first, let cursor = firstGroup.last?.id else {
            return CompactionSource(messages: [], cursorMessageId: nil, oversizedSource: nil)
        }
        return CompactionSource(messages: [], cursorMessageId: cursor, oversizedSource: representation(of: firstGroup))
    }

    func representation(of messages: [ChatMessage]) -> String {
        messages.map { message in
            let attachments = message.attachments.map(attachmentRepresentation).joined(separator: " ")
            let calls = message.toolCalls?.map {
                "[Tool call: \($0.function.name) \($0.function.arguments)]"
            }.joined(separator: " ") ?? ""
            let reasoning = message.reasoningContent.map { "[Reasoning: \($0)]" } ?? ""
            return "\(message.role.rawValue): \(message.content) \(reasoning) \(attachments) \(calls)"
        }.joined(separator: "\n")
    }

    func attachmentRepresentation(_ attachment: ChatMessage.Attachment) -> String {
        guard attachment.type == .pdf,
              let data = attachment.transientData ?? (try? attachmentRepository.load(attachment: attachment)) else {
            return "[Attachment: \(attachment.fileName)]"
        }
        let text = PDFTextExtractor.extract(from: data)
        return "[Document: \(attachment.fileName)]\n\(text)"
    }

    func summarizeOversizedSource(
        _ source: String,
        existingSummary: String?,
        configuration: CompactionConfiguration,
        model: LLMModel,
        builder: ContextWindowBuilder
    ) async throws -> String {
        var remaining = source
        var summary = existingSummary
        while !remaining.isEmpty {
            try Task.checkCancellation()
            let systemPrompt = summarySystemPrompt(existingSummary: summary)
            let fixedTokens = builder.estimatedInputTokens(messages: [], systemPrompt: systemPrompt)
            let availableTokens = builder.usableInputTokens(for: model.maxInputTokens ?? 0) - fixedTokens - 8
            guard availableTokens > 0 else { throw CompactConversationError.sourceCannotFit }
            let split = utf8Split(remaining, maximumBytes: availableTokens * 3)
            guard !split.prefix.isEmpty else { throw CompactConversationError.sourceCannotFit }
            let response = try await repository.sendMessage(
                messages: [
                    ChatMessage(role: .system, content: systemPrompt),
                    ChatMessage(role: .user, content: split.prefix)
                ],
                model: configuration.model,
                parameters: ModelParameters(maxTokens: summaryOutputTokens(configuration.maxOutputTokens))
            ).0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !response.isEmpty else { throw CompactConversationError.invalidSummaryResponse }
            summary = response
            remaining = split.remainder
        }
        return summary ?? ""
    }

    func utf8Split(_ text: String, maximumBytes: Int) -> (prefix: String, remainder: String) {
        var byteCount = 0
        var end = text.startIndex
        while end < text.endIndex {
            let next = text.index(after: end)
            let character = text[end..<next]
            let bytes = String(character).utf8.count
            guard byteCount + bytes <= maximumBytes else { break }
            byteCount += bytes
            end = next
        }
        return (String(text[..<end]), String(text[end...]))
    }

    func summaryOutputTokens(_ maxOutputTokens: Int?) -> Int {
        guard let maxOutputTokens else { return Self.maximumSummaryTokens }
        return min(Self.maximumSummaryTokens, max(1, maxOutputTokens))
    }

    func summarySystemPrompt(existingSummary: String?) -> String {
        let instruction = """
        Produce a concise, factual running summary of the conversation messages that follow. Preserve user preferences,
        decisions, open questions, constraints, facts, tool findings, and attachment references needed to continue.
        Return only the updated summary and do not mention that it is a summary.
        """
        guard let existingSummary = existingSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !existingSummary.isEmpty else { return instruction }
        return "\(instruction)\n\nExisting summary:\n\(existingSummary)"
    }
}
