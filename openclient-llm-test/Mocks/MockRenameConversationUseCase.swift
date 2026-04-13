//
//  MockRenameConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockRenameConversationUseCase: RenameConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var capturedId: UUID?
    var capturedTitle: String?
    var error: Error?

    // MARK: - Public

    func execute(_ conversationId: UUID, newTitle: String) throws {
        if let error { throw error }
        capturedId = conversationId
        capturedTitle = newTitle
    }
}
