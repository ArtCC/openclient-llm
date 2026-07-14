//
//  UpdateConversationTagsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol UpdateConversationTagsUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ conversationId: UUID, tags: [ConversationTag]) throws -> [ConversationTag]
}

struct UpdateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    @discardableResult
    func execute(_ conversationId: UUID, tags: [ConversationTag]) throws -> [ConversationTag] {
        var conversations = try repository.loadAll()
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return [] }
        let colorsByName = conversations.flatMap(\.tags).reduce(into: [String: TagColor]()) { colors, tag in
            if colors[tag.name] == nil {
                colors[tag.name] = tag.color
            }
        }
        var tagNames = Set<String>()
        let normalizedTags = tags.compactMap { tag -> ConversationTag? in
            let name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, tagNames.insert(name).inserted else { return nil }
            return ConversationTag(name: name, color: colorsByName[name] ?? tag.color)
        }
        conversations[index].tags = normalizedTags
        conversations[index].updatedAt = Date()
        try repository.save(conversations[index])
        return normalizedTags
    }
}
