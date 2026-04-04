//
//  PromptTemplate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct PromptTemplate: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    let id: UUID
    var title: String
    var content: String
    let isBuiltIn: Bool
    let createdAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        isBuiltIn: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}
