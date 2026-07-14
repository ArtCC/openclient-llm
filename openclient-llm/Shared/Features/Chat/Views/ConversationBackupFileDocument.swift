//
//  ConversationBackupFileDocument.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConversationBackupFileDocument: FileDocument {
    // MARK: - Properties

    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    // MARK: - Init

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    // MARK: - FileDocument

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
