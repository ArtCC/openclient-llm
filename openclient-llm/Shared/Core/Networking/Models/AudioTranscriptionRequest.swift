//
//  AudioTranscriptionRequest.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct AudioTranscriptionRequest: Sendable {
    let audioData: Data
    let model: String
    let language: String?
    let fileName: String
}
