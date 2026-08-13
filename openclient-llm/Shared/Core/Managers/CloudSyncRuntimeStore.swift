//
//  CloudSyncRuntimeStore.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@MainActor
protocol CloudSyncRuntimeStoreProtocol: AnyObject {
    var status: CloudSyncStatus { get }
    var isPreflightComplete: Bool { get }
    func publish(_ status: CloudSyncStatus)
    func begin(_ status: CloudSyncStatus) -> Int
    func isCurrent(generation: Int) -> Bool
    @discardableResult
    func completePreflight(generation: Int) -> Bool
    @discardableResult
    func publish(_ status: CloudSyncStatus, generation: Int) -> Bool
}

@Observable
@MainActor
final class CloudSyncRuntimeStore: CloudSyncRuntimeStoreProtocol {
    // MARK: - Properties

    static let shared: CloudSyncRuntimeStore = {
        let settingsManager = SettingsManager()
        return CloudSyncRuntimeStore(settingsManager: settingsManager)
    }()

    private(set) var status: CloudSyncStatus
    private(set) var isPreflightComplete: Bool
    private var generation = 0

    // MARK: - Init

    init(status: CloudSyncStatus = .disabled, isPreflightComplete: Bool = false) {
        self.status = status
        self.isPreflightComplete = isPreflightComplete
    }

    convenience init(settingsManager: SettingsManagerProtocol) {
        let status: CloudSyncStatus = settingsManager.getIsCloudSyncEnabled()
            ? .idle(lastSuccessfulSyncAt: settingsManager.getLastSuccessfulCloudSyncDate())
            : .disabled
        self.init(status: status)
    }

    // MARK: - Public

    func publish(_ status: CloudSyncStatus) {
        generation += 1
        self.status = status
        if status.invalidatesPreflight { isPreflightComplete = false }
    }

    func begin(_ status: CloudSyncStatus) -> Int {
        generation += 1
        self.status = status
        if status.invalidatesPreflight { isPreflightComplete = false }
        return generation
    }

    func isCurrent(generation: Int) -> Bool {
        generation == self.generation
    }

    @discardableResult
    func completePreflight(generation: Int) -> Bool {
        guard generation == self.generation else { return false }
        isPreflightComplete = true
        return true
    }

    @discardableResult
    func publish(_ status: CloudSyncStatus, generation: Int) -> Bool {
        guard generation == self.generation else { return false }
        self.status = status
        if status.invalidatesPreflight { isPreflightComplete = false }
        return true
    }
}

private extension CloudSyncStatus {
    var invalidatesPreflight: Bool {
        switch self {
        case .disabled, .checkingAvailability, .unavailable, .failed:
            true
        case .idle, .synchronizing, .waitingForDownloads, .synchronized, .incomplete:
            false
        }
    }
}
