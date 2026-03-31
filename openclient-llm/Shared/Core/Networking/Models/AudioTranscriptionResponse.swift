//
//  AudioTranscriptionResponse.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct AudioTranscriptionResponse: Decodable, Sendable {
    let text: String
}
