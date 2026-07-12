//
//  ConversationSyncResult.swift
//  openclient-llm
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum ConversationSyncResult: Equatable, Sendable {
    case synchronized
    case pendingDownload
    case unavailable
    case failed
}
