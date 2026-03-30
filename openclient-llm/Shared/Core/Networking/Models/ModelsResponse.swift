//
//  ModelsResponse.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ModelsResponse: Decodable, Sendable {
    let data: [ModelData]

    struct ModelData: Decodable, Sendable {
        let id: String
        let ownedBy: String?
    }
}
