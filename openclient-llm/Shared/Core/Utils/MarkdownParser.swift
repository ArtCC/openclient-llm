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
    case heading(text: String, level: Int)
}

// MARK: - MarkdownParser

struct MarkdownParser: Sendable {
    // MARK: - Public

    static func parse(_ raw: String) -> [MessageBlock] {
        let lines = raw.components(separatedBy: "\n")

        var blocks: [MessageBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.hasPrefix("```") {
                let language = extractLanguage(from: line)
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    if lines[index].hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }

                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(code: code, language: language))
            } else {
                var textLines: [String] = []

                while index < lines.count && !lines[index].hasPrefix("```") {
                    let currentLine = lines[index]

                    if let (level, headingText) = extractHeading(from: currentLine) {
                        let accumulated = textLines.joined(separator: "\n")
                        if !accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            blocks.append(.text(accumulated))
                        }
                        textLines = []
                        blocks.append(.heading(text: headingText, level: level))
                    } else {
                        textLines.append(currentLine)
                    }

                    index += 1
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

    static func extractHeading(from line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level) + " "
            if trimmed.hasPrefix(prefix) {
                let text = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return (level, text)
            }
        }
        return nil
    }
}
