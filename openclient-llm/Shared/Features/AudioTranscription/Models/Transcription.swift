//
//  Transcription.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct Transcription: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: UUID
    let text: String
    let modelId: String
    let duration: TimeInterval
    let createdAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        text: String,
        modelId: String,
        duration: TimeInterval = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.modelId = modelId
        self.duration = duration
        self.createdAt = createdAt
    }
}
