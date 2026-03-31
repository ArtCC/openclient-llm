//
//  ImageGenerationResponse.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ImageGenerationResponse: Decodable, Sendable {
    let created: Int
    let data: [ImageData]

    struct ImageData: Decodable, Sendable {
        let url: String?
        let b64Json: String?
        let revisedPrompt: String?
    }
}
