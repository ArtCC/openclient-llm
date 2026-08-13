//
//  ConversationSyncOperationError.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum ConversationSyncOperationError: LocalizedError, Equatable {
    case pendingDownload
    case unavailable
    case failed

    init?(result: ConversationSyncResult) {
        switch result {
        case .synchronized:
            return nil
        case .pendingDownload:
            self = .pendingDownload
        case .unavailable:
            self = .unavailable
        case .failed:
            self = .failed
        }
    }

    var errorDescription: String? {
        switch self {
        case .pendingDownload:
            String(localized: "The cloud deletion is waiting for required downloads.")
        case .unavailable:
            String(localized: "The cloud deletion could not be completed because iCloud is unavailable.")
        case .failed:
            String(localized: "The cloud deletion could not be completed.")
        }
    }
}
