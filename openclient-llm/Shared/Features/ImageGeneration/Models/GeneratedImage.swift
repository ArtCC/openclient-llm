//
//  GeneratedImage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct GeneratedImage: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: UUID
    let prompt: String
    let revisedPrompt: String?
    let imageData: Data
    let modelId: String
    let createdAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        prompt: String,
        revisedPrompt: String? = nil,
        imageData: Data,
        modelId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.revisedPrompt = revisedPrompt
        self.imageData = imageData
        self.modelId = modelId
        self.createdAt = createdAt
    }
}
