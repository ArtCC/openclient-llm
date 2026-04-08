//
//  ModelInfoResponse.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ModelInfoResponse: Decodable, Sendable {
    let data: [ModelInfoData]

    struct ModelInfoData: Decodable, Sendable {
        let modelName: String
        let modelInfo: ModelInfo?
    }

    struct ModelInfo: Decodable, Sendable {
        let maxTokens: Int?
        let maxInputTokens: Int?
        let maxOutputTokens: Int?
        let supportsVision: Bool?
        let supportsFunctionCalling: Bool?
        let supportsParallelFunctionCalling: Bool?
        let supportsResponseSchema: Bool?
        let supportsWebSearch: Bool?
        let mode: String?
        let litellmProvider: String?
    }
}
