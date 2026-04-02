//
//  TTSVoice.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct TTSVoice: RawRepresentable, Equatable, Hashable, Sendable {
    // MARK: - Properties

    let rawValue: String

    static let alloy = TTSVoice(rawValue: "alloy")
    static let echo = TTSVoice(rawValue: "echo")
    static let fable = TTSVoice(rawValue: "fable")
    static let onyx = TTSVoice(rawValue: "onyx")
    static let nova = TTSVoice(rawValue: "nova")
    static let shimmer = TTSVoice(rawValue: "shimmer")

    static let presets: [TTSVoice] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]

    // MARK: - Init

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
