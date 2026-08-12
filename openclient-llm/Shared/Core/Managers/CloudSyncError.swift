//
//  CloudSyncError.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum CloudSyncError: LocalizedError, Equatable {
    case containerUnavailable
    case containerIdentityChanged
    case cloudContentChanged
    case requiredDownloadPending
    case missingAttachment
    case invalidAttachmentPath
    case invalidConversationData
    case invalidProfileData
    case staleConversationRevision
    case staleProfileRevision
    case conflictingProfileRevision
    case operationFenced

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            String(localized: "The iCloud container is unavailable.")
        case .containerIdentityChanged:
            String(localized: "The iCloud account changed during synchronization.")
        case .cloudContentChanged:
            String(localized: "iCloud data changed during synchronization.")
        case .requiredDownloadPending:
            String(localized: "Required iCloud data is still downloading.")
        case .missingAttachment:
            String(localized: "A synchronized conversation attachment is missing.")
        case .invalidAttachmentPath:
            String(localized: "A synchronized conversation attachment has an invalid path.")
        case .invalidConversationData:
            String(localized: "A synchronized conversation contains invalid data.")
        case .invalidProfileData:
            String(localized: "The local profile contains invalid data.")
        case .staleConversationRevision:
            String(localized: "The conversation changed or was deleted before this save completed.")
        case .staleProfileRevision:
            String(localized: "The profile changed or was deleted before this save completed.")
        case .conflictingProfileRevision:
            String(localized: "The profile has conflicting changes with the same revision.")
        case .operationFenced:
            String(localized: "The cloud operation was cancelled by an app data reset.")
        }
    }
}
