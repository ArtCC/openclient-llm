//
//  CloudAccountAssociation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

nonisolated enum CloudAccountAssociationState: Equatable, Sendable {
    case unavailable
    case unassociated
    case matched
    case changed
}

nonisolated enum CloudAccountAssociationError: Error, Equatable, Sendable {
    case unavailable
    case accountChanged
}

protocol CloudAccountAssociationProtocol: Sendable {
    func state() -> CloudAccountAssociationState
    func currentAccountFingerprint() -> String?
    func approveCurrentAccount(expectedFingerprint: String) throws
}

final class CloudAccountAssociation: CloudAccountAssociationProtocol {
    // MARK: - Properties

    static let shared = CloudAccountAssociation()

    private let settingsManager: SettingsManagerProtocol
    private let containerProvider: CloudContainerProviding

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        containerProvider: CloudContainerProviding = UbiquityCloudContainerProvider(fileManager: .default)
    ) {
        self.settingsManager = settingsManager
        self.containerProvider = containerProvider
    }

    // MARK: - Public

    func state() -> CloudAccountAssociationState {
        guard let fingerprint = currentFingerprint() else { return .unavailable }
        guard let accepted = settingsManager.getAcceptedCloudAccountFingerprint() else { return .unassociated }
        return accepted == fingerprint ? .matched : .changed
    }

    func currentAccountFingerprint() -> String? {
        guard let session = containerProvider.currentSession() else { return nil }
        return fingerprint(for: session.identity)
    }

    func approveCurrentAccount(expectedFingerprint: String) throws {
        guard let fingerprint = currentAccountFingerprint() else { throw CloudAccountAssociationError.unavailable }
        guard fingerprint == expectedFingerprint else { throw CloudAccountAssociationError.accountChanged }
        settingsManager.setAcceptedCloudAccountFingerprint(fingerprint)
    }
}

// MARK: - Private

private extension CloudAccountAssociation {
    func currentFingerprint() -> String? {
        currentAccountFingerprint()
    }

    func fingerprint(for identity: Data) -> String {
        SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    }
}
