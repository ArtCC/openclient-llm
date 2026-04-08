//
//  GetUserProfileContextUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GetUserProfileContextUseCaseProtocol: Sendable {
    func execute() -> String
}

struct GetUserProfileContextUseCase: GetUserProfileContextUseCaseProtocol {
    // MARK: - Properties

    private let manager: UserProfileManagerProtocol

    // MARK: - Init

    init(manager: UserProfileManagerProtocol = UserProfileManager()) {
        self.manager = manager
    }

    // MARK: - Execute

    func execute() -> String {
        manager.getProfile().systemPromptContext
    }
}
