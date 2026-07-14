//
//  PDFTextExtractor.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
import PDFKit

nonisolated struct PDFTextExtractor: Sendable {
    static func extract(from data: Data, maximumPages: Int = 20, maximumCharacters: Int = 100_000) -> String {
        guard let document = PDFDocument(data: data) else { return "" }
        var text = ""
        for pageIndex in 0..<min(document.pageCount, maximumPages) {
            guard let pageText = document.page(at: pageIndex)?.string else { continue }
            let remaining = maximumCharacters - text.count
            guard remaining > 0 else { break }
            text += String(pageText.prefix(remaining)) + "\n"
        }
        return text
    }
}
