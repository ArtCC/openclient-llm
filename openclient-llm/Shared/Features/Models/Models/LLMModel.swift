//
//  LLMModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct LLMModel: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: String
    let ownedBy: String

    // MARK: - Init

    init(id: String, ownedBy: String = "") {
        self.id = id
        self.ownedBy = ownedBy
    }
}
