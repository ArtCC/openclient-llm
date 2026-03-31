//
//  MarkdownParser.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - MessageBlock

enum MessageBlock: Equatable, Sendable {
    case text(String)
    case codeBlock(code: String, language: String?)
}

// MARK: - MarkdownParser

struct MarkdownParser: Sendable {
    // MARK: - Public

    static func parse(_ raw: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var lines = raw.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                let language = extractLanguage(from: line)
                var codeLines: [String] = []
                i += 1

                while i < lines.count {
                    if lines[i].hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }

                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(code: code, language: language))
            } else {
                var textLines: [String] = []

                while i < lines.count && !lines[i].hasPrefix("```") {
                    textLines.append(lines[i])
                    i += 1
                }

                let text = textLines.joined(separator: "\n")
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(text))
                }
            }
        }

        return blocks
    }
}

// MARK: - Private

private extension MarkdownParser {
    static func extractLanguage(from fenceLine: String) -> String? {
        let trimmed = fenceLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 3 else { return nil }
        let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return lang.isEmpty ? nil : lang
    }
}
