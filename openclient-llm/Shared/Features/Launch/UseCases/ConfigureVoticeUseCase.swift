//
//  ConfigureVoticeUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@MainActor
protocol ConfigureVoticeUseCaseProtocol: Sendable {
    func execute(userIsPremium: Bool) throws
}

struct ConfigureVoticeUseCase: ConfigureVoticeUseCaseProtocol {
    // MARK: - Properties

    private let voticeManager: VoticeManagerProtocol

    // MARK: - Init

    init(voticeManager: VoticeManagerProtocol = VoticeManager()) {
        self.voticeManager = voticeManager
    }

    // MARK: - Execute

    func execute(userIsPremium: Bool) throws {
        try voticeManager.configure(userIsPremium)
    }
}
