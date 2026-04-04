//
//  MockExportConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockExportConversationUseCase: ExportConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<Data, Error> = .success(Data("{\"id\":\"test\"}".utf8))
    var executedConversations: [Conversation] = []

    // MARK: - Execute

    func execute(_ conversation: Conversation) throws -> Data {
        executedConversations.append(conversation)
        return try result.get()
    }
}
