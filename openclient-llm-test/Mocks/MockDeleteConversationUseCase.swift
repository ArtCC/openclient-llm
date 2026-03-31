//
//  MockDeleteConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockDeleteConversationUseCase: DeleteConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var deletedIds: [UUID] = []
    var error: Error?

    // MARK: - Execute

    func execute(_ conversationId: UUID) throws {
        if let error { throw error }
        deletedIds.append(conversationId)
    }
}
