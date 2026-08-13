//
//  EnableCloudSyncUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol EnableCloudSyncUseCaseProtocol: Sendable {
    func execute() async throws -> CloudSyncEnablementPreflight
}

nonisolated enum CloudSyncEnablementPreflight: Equatable, Sendable {
    case ready
    case profileConflict
}

struct EnableCloudSyncUseCase: EnableCloudSyncUseCaseProtocol {
    // MARK: - Properties

    private let cloudSyncManager: CloudSyncManagerProtocol
    private let userProfileManager: UserProfileManagerProtocol
    private let hasUbiquityIdentity: @Sendable () -> Bool

    // MARK: - Init

    init(
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        hasUbiquityIdentity: @escaping @Sendable () -> Bool = {
            FileManager.default.ubiquityIdentityToken != nil
        }
    ) {
        self.cloudSyncManager = cloudSyncManager
        self.userProfileManager = userProfileManager
        self.hasUbiquityIdentity = hasUbiquityIdentity
    }

    // MARK: - Execute

    func execute() async throws -> CloudSyncEnablementPreflight {
        guard hasUbiquityIdentity() else { throw CloudSyncPreflightError.accountUnavailable }
        guard await cloudSyncManager.checkCloudAvailability() else {
            throw CloudSyncPreflightError.containerUnavailable
        }

        var pendingCategories: Set<CloudSyncStatus.DataCategory> = []
        var unavailableCategories: [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason] = [:]
        var failureReasons: [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason] = [:]
        try Task.checkCancellation()
        preflightConversations(
            pendingCategories: &pendingCategories,
            unavailableCategories: &unavailableCategories,
            failureReasons: &failureReasons
        )
        try Task.checkCancellation()
        let cloudProfile = await preflightProfile(
            pendingCategories: &pendingCategories,
            unavailableCategories: &unavailableCategories,
            failureReasons: &failureReasons
        )
        try Task.checkCancellation()
        await preflightMemory(
            pendingCategories: &pendingCategories,
            unavailableCategories: &unavailableCategories,
            failureReasons: &failureReasons
        )
        try Task.checkCancellation()
        await preflightPromptTemplates(
            pendingCategories: &pendingCategories,
            unavailableCategories: &unavailableCategories,
            failureReasons: &failureReasons
        )
        try Task.checkCancellation()
        let localProfile = preflightLocalProfile(
            pendingCategories: &pendingCategories,
            unavailableCategories: &unavailableCategories,
            failureReasons: &failureReasons
        )
        try Task.checkCancellation()
        let issues = CloudSyncStatus.Issues(
            pendingCategories: pendingCategories,
            unavailableCategories: unavailableCategories,
            failureReasons: failureReasons
        )
        if !issues.isEmpty { throw CloudSyncPreflightError.issues(issues) }
        guard let localProfile, let cloudProfile else { return .ready }
        return hasEqualRevisionProfileConflict(local: localProfile, cloud: cloudProfile) ? .profileConflict : .ready
    }
}

nonisolated enum CloudSyncPreflightError: Error, Equatable, Sendable {
    case accountUnavailable
    case containerUnavailable
    case issues(CloudSyncStatus.Issues)
}

// MARK: - Private

private extension EnableCloudSyncUseCase {
    func preflightConversations(
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) {
        do {
            _ = try cloudSyncManager.loadConversationSyncSnapshot()
        } catch {
            collect(
                error,
                categories: [.conversations, .attachments],
                pendingCategories: &pendingCategories,
                unavailableCategories: &unavailableCategories,
                failureReasons: &failureReasons
            )
        }
    }

    func preflightProfile(
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) async -> CloudUserProfileState? {
        do {
            return try await cloudSyncManager.loadProfileSyncSnapshot().state
        } catch {
            collect(
                error,
                categories: [.profile],
                pendingCategories: &pendingCategories,
                unavailableCategories: &unavailableCategories,
                failureReasons: &failureReasons
            )
            return nil
        }
    }

    func preflightMemory(
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) async {
        do {
            _ = try await cloudSyncManager.loadMemorySyncSnapshot()
        } catch {
            collect(
                error,
                categories: [.memory],
                pendingCategories: &pendingCategories,
                unavailableCategories: &unavailableCategories,
                failureReasons: &failureReasons
            )
        }
    }

    func preflightPromptTemplates(
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) async {
        do {
            _ = try await cloudSyncManager.loadTemplatesFromCloud()
        } catch {
            collect(
                error,
                categories: [.promptTemplates],
                pendingCategories: &pendingCategories,
                unavailableCategories: &unavailableCategories,
                failureReasons: &failureReasons
            )
        }
    }

    func preflightLocalProfile(
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) -> LocalUserProfileState? {
        do {
            return try userProfileManager.getLocalProfileState()
        } catch {
            collect(
                error,
                categories: [.profile],
                pendingCategories: &pendingCategories,
                unavailableCategories: &unavailableCategories,
                failureReasons: &failureReasons
            )
            return nil
        }
    }

    func hasEqualRevisionProfileConflict(
        local: LocalUserProfileState,
        cloud: CloudUserProfileState
    ) -> Bool {
        guard case .profile(let localProfile) = local,
              case .profile(let cloudProfile) = cloud else { return false }
        return localProfile.modifiedAt == cloudProfile.modifiedAt && localProfile != cloudProfile
    }

    func collect(
        _ error: Error,
        categories: Set<CloudSyncStatus.DataCategory>,
        pendingCategories: inout Set<CloudSyncStatus.DataCategory>,
        unavailableCategories: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.UnavailableReason],
        failureReasons: inout [CloudSyncStatus.DataCategory: CloudSyncStatus.FailureReason]
    ) {
        if error is CancellationError { return }
        if let cloudError = error as? CloudSyncError {
            switch cloudError {
            case .requiredDownloadPending:
                pendingCategories.formUnion(categories)
                return
            case .containerUnavailable, .containerIdentityChanged:
                for category in categories { unavailableCategories[category] = .containerUnavailable }
                return
            default:
                break
            }
        }
        let affectedCategories = error is CloudSyncManifest.ValidationError
            ? Set(CloudSyncStatus.DataCategory.allCases)
            : categories
        for category in affectedCategories { failureReasons[category] = failureReason(for: error) }
    }

    func failureReason(for error: Error) -> CloudSyncStatus.FailureReason {
        if error is CloudSyncManifest.ValidationError { return .unsupportedSchema }
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteOutOfSpace {
            return .insufficientStorage
        }
        switch error as? CloudSyncError {
        case .invalidAttachmentPath, .invalidConversationData, .invalidProfileData:
            return .invalidData
        case .conflictingProfileRevision:
            return .profileConflict
        default:
            return .fileAccess
        }
    }
}
