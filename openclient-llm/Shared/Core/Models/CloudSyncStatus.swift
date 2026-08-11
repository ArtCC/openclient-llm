//
//  CloudSyncStatus.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum CloudSyncStatus: Equatable, Sendable {
    // MARK: - Types

    enum DataCategory: String, CaseIterable, Hashable, Sendable {
        case conversations
        case attachments
        case profile
        case memory
        case promptTemplates
    }

    enum UnavailableReason: CaseIterable, Equatable, Sendable {
        case accountUnavailable
        case containerUnavailable
    }

    enum FailureReason: CaseIterable, Equatable, Sendable {
        case accountChanged
        case profileConflict
        case unsupportedSchema
        case invalidData
        case fileAccess
        case insufficientStorage
        case other
    }

    struct Failure: Equatable, Sendable {
        let reason: FailureReason
        let affectedCategories: Set<DataCategory>
    }

    struct Issues: Equatable, Sendable {
        let pendingCategories: Set<DataCategory>
        let unavailableCategories: [DataCategory: UnavailableReason]
        let failureReasons: [DataCategory: FailureReason]

        var isEmpty: Bool {
            pendingCategories.isEmpty && unavailableCategories.isEmpty && failureReasons.isEmpty
        }
    }

    // MARK: - States

    case disabled
    case checkingAvailability
    case idle(lastSuccessfulSyncAt: Date?)
    case synchronizing
    case waitingForDownloads
    case synchronized(lastSuccessfulSyncAt: Date)
    case unavailable(UnavailableReason)
    case failed(Failure)
    case incomplete(Issues)
}
