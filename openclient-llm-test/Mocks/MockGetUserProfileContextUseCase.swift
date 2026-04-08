//
//  MockGetUserProfileContextUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

struct MockGetUserProfileContextUseCase: GetUserProfileContextUseCaseProtocol, Sendable {
    // MARK: - Properties

    var context: String = ""

    // MARK: - GetUserProfileContextUseCaseProtocol

    func execute() -> String {
        context
    }
}
