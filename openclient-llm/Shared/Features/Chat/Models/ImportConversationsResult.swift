//
//  ImportConversationsResult.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ImportConversationsResult: Equatable, Sendable {
    // MARK: - Properties

    let importedConversationCount: Int
    let restoredAttachmentCount: Int
    let skippedAttachmentCount: Int
}
