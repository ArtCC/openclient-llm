//
//  MockLoadConversationsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockLoadConversationsUseCase: LoadConversationsUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<[Conversation], Error> = .success([])

    // MARK: - Execute

    func execute() throws -> [Conversation] {
        try result.get()
    }
}
