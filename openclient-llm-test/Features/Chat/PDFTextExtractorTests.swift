//
//  PDFTextExtractorTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import PDFKit
import XCTest
@testable import openclient_llm

@MainActor
final class PDFTextExtractorTests: XCTestCase {
    // MARK: - Tests — extract

    func test_extract_emptyData_returnsEmptyString() {
        // Given
        let emptyData = Data()

        // When
        let result = PDFTextExtractor.extract(from: emptyData)

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_extract_nonPDFData_returnsEmptyString() {
        // Given
        let nonPDFData = Data("not a pdf".utf8)

        // When
        let result = PDFTextExtractor.extract(from: nonPDFData)

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_extract_validPDFWithText_returnsText() {
        // Given
        let pdfData = createPDFData(withText: "Hello World")

        // When
        let result = PDFTextExtractor.extract(from: pdfData)

        // Then
        XCTAssertTrue(result.contains("Hello World"))
    }

    func test_extract_respectsMaximumPages() {
        // Given
        let pdfData = createMultiPagePDF(pageCount: 5, text: "Content")

        // When
        let result = PDFTextExtractor.extract(from: pdfData, maximumPages: 2)

        // Then
        let occurrences = result.components(separatedBy: "Content").count - 1
        XCTAssertEqual(occurrences, 2)
    }

    func test_extract_respectsMaximumCharacters() {
        // Given
        let pdfData = createPDFData(withText: String(repeating: "A", count: 500))

        // When
        let result = PDFTextExtractor.extract(from: pdfData, maximumCharacters: 100)

        // Then
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertLessThanOrEqual(trimmed.count, 100)
    }

    // MARK: - Helpers

    private func createPDFData(withText text: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            format: format
        )
        return renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
        }
    }

    private func createMultiPagePDF(pageCount: Int, text: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            format: format
        )
        return renderer.pdfData { context in
            for _ in 0..<pageCount {
                context.beginPage()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
            }
        }
    }
}
