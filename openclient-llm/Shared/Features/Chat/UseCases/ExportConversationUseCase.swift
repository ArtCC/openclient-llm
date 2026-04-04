//
//  ExportConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ExportConversationUseCaseProtocol: Sendable {
    func execute(_ conversation: Conversation) throws -> Data
}

struct ExportConversationUseCase: ExportConversationUseCaseProtocol {
    // MARK: - Execute

    func execute(_ conversation: Conversation) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(conversation)
    }
}
