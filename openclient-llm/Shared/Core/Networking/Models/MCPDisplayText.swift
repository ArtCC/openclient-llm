//
//  MCPDisplayText.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum MCPDisplayText {
    private static let bidirectionalControlScalars: Set<UInt32> = [
        0x061C, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069
    ]

    static func sanitize(_ value: String, fallback: String, maximumLength: Int) -> String {
        var sanitized = ""
        for scalar in value.unicodeScalars {
            if bidirectionalControlScalars.contains(scalar.value) { continue }
            if CharacterSet.controlCharacters.contains(scalar) {
                sanitized.append(" ")
            } else {
                sanitized.append(Character(String(scalar)))
            }
        }
        let collapsed = sanitized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        return String(collapsed.prefix(maximumLength))
    }

    static func escapedForCodeDisplay(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            let preservesFormatting = scalar.value == 9 || scalar.value == 10 || scalar.value == 13
            if bidirectionalControlScalars.contains(scalar.value)
                || (CharacterSet.controlCharacters.contains(scalar) && !preservesFormatting) {
                escaped += String(format: "\\u{%04X}", scalar.value)
            } else {
                escaped.append(Character(String(scalar)))
            }
        }
        return escaped
    }

    static func wrappedToolResultForModel(_ value: String, maximumBytes: Int = .max) -> String {
        guard maximumBytes >= 2 else { return "" }
        let fullResult = encodedToolResult(value)
        guard fullResult.utf8.count > maximumBytes else { return fullResult }
        let marker = "\n[Tool result truncated]"
        var lowerBound = 0
        var upperBound = value.count
        var bestResult = encodedToolResult("")
        while lowerBound <= upperBound {
            let candidateLength = (lowerBound + upperBound) / 2
            let candidate = String(value.prefix(candidateLength)) + marker
            let encoded = encodedToolResult(candidate)
            if encoded.utf8.count <= maximumBytes {
                bestResult = encoded
                lowerBound = candidateLength + 1
            } else {
                upperBound = candidateLength - 1
            }
        }
        return bestResult.utf8.count <= maximumBytes ? bestResult : "{}"
    }

    private static func encodedToolResult(_ value: String) -> String {
        let payload = MCPModelToolResult(untrustedExternalToolResult: escapedForCodeDisplay(value))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload),
              let result = String(data: data, encoding: .utf8) else { return "{}" }
        return result
    }
}

private nonisolated struct MCPModelToolResult: Encodable {
    let untrustedExternalToolResult: String
}
