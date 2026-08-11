//
//  CloudSyncStatusPresentation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct CloudSyncStatusPresentation: Equatable, Sendable {
    let title: String
    let detail: String?
    let systemImage: String
    let canRetry: Bool
    let showsProgress: Bool
    let requiresAccountReview: Bool

    init(
        title: String,
        detail: String?,
        systemImage: String,
        canRetry: Bool,
        showsProgress: Bool,
        requiresAccountReview: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.canRetry = canRetry
        self.showsProgress = showsProgress
        self.requiresAccountReview = requiresAccountReview
    }

    static func make(
        for status: CloudSyncStatus,
        lastSuccessfulSyncAt: Date? = nil
    ) -> CloudSyncStatusPresentation {
        switch status {
        case .disabled:
            .init(
                title: String(localized: "iCloud Sync is off"),
                detail: lastSuccessDetail(lastSuccessfulSyncAt),
                systemImage: "icloud.slash",
                canRetry: false,
                showsProgress: false
            )
        case .checkingAvailability:
            progress(
                title: String(localized: "Checking iCloud availability..."),
                lastSuccessfulSyncAt: lastSuccessfulSyncAt
            )
        case .idle(let date):
            .init(
                title: String(localized: "Ready to synchronize"),
                detail: lastSuccessDetail(date),
                systemImage: "icloud",
                canRetry: false,
                showsProgress: false
            )
        case .synchronizing:
            progress(
                title: String(localized: "Synchronizing all app data..."),
                lastSuccessfulSyncAt: lastSuccessfulSyncAt
            )
        case .waitingForDownloads:
            waitingForDownloads(lastSuccessfulSyncAt: lastSuccessfulSyncAt)
        case .synchronized(let date):
            .init(
                title: String(localized: "All app data is synchronized"),
                detail: lastSuccessDetail(date),
                systemImage: "checkmark.icloud",
                canRetry: false,
                showsProgress: false
            )
        case .unavailable(let reason):
            unavailable(reason, lastSuccessfulSyncAt: lastSuccessfulSyncAt)
        case .failed(let failure):
            failed(failure, lastSuccessfulSyncAt: lastSuccessfulSyncAt)
        case .incomplete(let issues):
            incomplete(issues, lastSuccessfulSyncAt: lastSuccessfulSyncAt)
        }
    }
}

// MARK: - Private

private extension CloudSyncStatusPresentation {
    static func waitingForDownloads(lastSuccessfulSyncAt: Date?) -> CloudSyncStatusPresentation {
        .init(
            title: String(localized: "Waiting for iCloud downloads"),
            detail: appendingLastSuccess(
                to: String(localized: "No cloud changes will be written until required downloads finish."),
                date: lastSuccessfulSyncAt
            ),
            systemImage: "icloud.and.arrow.down",
            canRetry: true,
            showsProgress: true
        )
    }

    static func progress(title: String, lastSuccessfulSyncAt: Date?) -> CloudSyncStatusPresentation {
        .init(
            title: title,
            detail: lastSuccessDetail(lastSuccessfulSyncAt),
            systemImage: "icloud",
            canRetry: false,
            showsProgress: true
        )
    }

    static func unavailable(
        _ reason: CloudSyncStatus.UnavailableReason,
        lastSuccessfulSyncAt: Date?
    ) -> CloudSyncStatusPresentation {
        let detail = switch reason {
        case .accountUnavailable:
            String(localized: "Sign in to iCloud, then retry. Sync remains enabled.")
        case .containerUnavailable:
            String(localized: "The app's iCloud container is unavailable. Your local data is retained.")
        }
        return .init(
            title: String(localized: "iCloud is unavailable"),
            detail: appendingLastSuccess(to: detail, date: lastSuccessfulSyncAt),
            systemImage: "exclamationmark.icloud",
            canRetry: true,
            showsProgress: false
        )
    }

    static func failed(
        _ failure: CloudSyncStatus.Failure,
        lastSuccessfulSyncAt: Date?
    ) -> CloudSyncStatusPresentation {
        let categoryList = localizedCategoryList(failure.affectedCategories)
        let detail = switch failure.reason {
        case .accountChanged:
            String(localized: "Review the current iCloud account before any local or cloud data is changed.")
        case .profileConflict:
            String(localized: "The local and iCloud profiles have conflicting changes with the same revision.")
        case .unsupportedSchema:
            String(localized: "This iCloud data format is not supported by this version of the app.")
        case .invalidData:
            String(format: String(localized: "Invalid synchronized data was preserved for: %@."), categoryList)
        case .fileAccess:
            String(format: String(localized: "iCloud files could not be accessed for: %@."), categoryList)
        case .insufficientStorage:
            String(localized: "There is not enough storage to complete synchronization.")
        case .other:
            String(format: String(localized: "Synchronization failed for: %@. Local data was retained."), categoryList)
        }
        return .init(
            title: failureTitle(failure.reason),
            detail: appendingLastSuccess(to: detail, date: lastSuccessfulSyncAt),
            systemImage: "exclamationmark.triangle",
            canRetry: true,
            showsProgress: false,
            requiresAccountReview: failure.reason == .accountChanged
        )
    }

    static func incomplete(
        _ issues: CloudSyncStatus.Issues,
        lastSuccessfulSyncAt: Date?
    ) -> CloudSyncStatusPresentation {
        var details: [String] = []
        if !issues.failureReasons.isEmpty {
            details.append(failureDetail(issues.failureReasons))
        }
        if !issues.pendingCategories.isEmpty {
            let categories = localizedCategoryList(issues.pendingCategories)
            details.append(String(
                format: String(localized: "Waiting for iCloud downloads for: %@."),
                categories
            ))
        }
        if !issues.unavailableCategories.isEmpty {
            details.append(unavailableDetail(issues.unavailableCategories))
        }
        let detail = details.joined(separator: " ")
        return .init(
            title: issues.failureReasons.isEmpty
                ? String(localized: "Synchronization is incomplete")
                : String(localized: "Synchronization failed"),
            detail: appendingLastSuccess(to: detail, date: lastSuccessfulSyncAt),
            systemImage: "exclamationmark.triangle",
            canRetry: true,
            showsProgress: !issues.pendingCategories.isEmpty
        )
    }

    static func failureDetail(
        _ reasons: [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) -> String {
        CloudSyncStatus.FailureReason.allCases.compactMap { reason in
            let categories = Set(reasons.compactMap { $0.value == reason ? $0.key : nil })
            guard !categories.isEmpty else { return nil }
            return String(
                format: String(localized: "%@: %@."),
                localizedFailureReason(reason),
                localizedCategoryList(categories)
            )
        }.joined(separator: " ")
    }

    static func localizedFailureReason(_ reason: CloudSyncStatus.FailureReason) -> String {
        switch reason {
        case .accountChanged: String(localized: "iCloud account review required")
        case .profileConflict: String(localized: "Profile conflict")
        case .unsupportedSchema: String(localized: "Unsupported data format")
        case .invalidData: String(localized: "Invalid synchronized data")
        case .fileAccess: String(localized: "iCloud file access failed")
        case .insufficientStorage: String(localized: "Insufficient storage")
        case .other: String(localized: "Synchronization failed")
        }
    }

    static func failureTitle(_ reason: CloudSyncStatus.FailureReason) -> String {
        switch reason {
        case .accountChanged: String(localized: "Review iCloud account")
        case .profileConflict: String(localized: "Profile synchronization needs a decision")
        default: String(localized: "Synchronization failed")
        }
    }

    static func unavailableDetail(
        _ reasons: [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason]
    ) -> String {
        CloudSyncStatus.UnavailableReason.allCases.compactMap { reason in
            let categories = Set(reasons.compactMap { $0.value == reason ? $0.key : nil })
            guard !categories.isEmpty else { return nil }
            let reasonText = switch reason {
            case .accountUnavailable: String(localized: "iCloud account unavailable")
            case .containerUnavailable: String(localized: "iCloud container unavailable")
            }
            return String(
                format: String(localized: "%@: %@."),
                reasonText,
                localizedCategoryList(categories)
            )
        }.joined(separator: " ")
    }

    static func lastSuccessDetail(_ date: Date?) -> String? {
        guard let date else { return String(localized: "No complete synchronization has succeeded yet.") }
        return String(
            format: String(localized: "Last successful synchronization: %@"),
            date.formatted(date: .abbreviated, time: .shortened)
        )
    }

    static func appendingLastSuccess(to detail: String, date: Date?) -> String {
        guard let lastSuccess = lastSuccessDetail(date) else { return detail }
        return "\(detail) \(lastSuccess)"
    }

    static func localizedCategoryList(_ categories: Set<CloudSyncStatus.DataCategory>) -> String {
        guard !categories.isEmpty else { return String(localized: "All synchronized data") }
        let names = CloudSyncStatus.DataCategory.allCases.filter(categories.contains).map { category in
            switch category {
            case .conversations: String(localized: "Conversations")
            case .attachments: String(localized: "Attachments (part of conversations)")
            case .profile: String(localized: "Profile")
            case .memory: String(localized: "Memory")
            case .promptTemplates: String(localized: "Prompt templates")
            }
        }
        return ListFormatter.localizedString(byJoining: names)
    }
}
