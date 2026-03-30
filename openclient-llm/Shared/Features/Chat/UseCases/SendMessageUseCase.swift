//
//  SendMessageUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SendMessageUseCaseProtocol: Sendable {
    func execute(messages: [ChatMessage], model: String) async throws -> String
}

struct SendMessageUseCase: SendMessageUseCaseProtocol {
    // MARK: - Properties

    private let repository: ChatRepositoryProtocol

    // MARK: - Init

    init(repository: ChatRepositoryProtocol = ChatRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(messages: [ChatMessage], model: String) async throws -> String {
        try await repository.sendMessage(messages: messages, model: model)
    }
}
