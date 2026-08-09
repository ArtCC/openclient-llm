//
//  LaunchViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class LaunchViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case onboardingCompleted
    }

    enum State: Equatable {
        case loading
        case onboarding
        case home
        case maintenance
        case forceUpdate(RemoteConfig.PlatformUpdate)
    }

    private(set) var state: State

    private let checkOnboardingUseCase: CheckOnboardingUseCaseProtocol
    private let resetAppDataUseCase: ResetAppDataUseCaseProtocol
    private let configureVoticeUseCase: ConfigureVoticeUseCaseProtocol
    private let attachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol
    private let remoteConfigManager: RemoteConfigManagerProtocol
    private let currentVersion: String?
    private let launchDelay: Duration

    // MARK: - Init

    init(
        state: State = .loading,
        checkOnboardingUseCase: CheckOnboardingUseCaseProtocol = CheckOnboardingUseCase(),
        resetAppDataUseCase: ResetAppDataUseCaseProtocol = ResetAppDataUseCase(),
        configureVoticeUseCase: ConfigureVoticeUseCaseProtocol = ConfigureVoticeUseCase(),
        attachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol = AttachmentMigrationUseCase(),
        remoteConfigManager: RemoteConfigManagerProtocol = RemoteConfigManager(),
        currentVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        launchDelay: Duration = .milliseconds(1000)
    ) {
        self.state = state
        self.checkOnboardingUseCase = checkOnboardingUseCase
        self.resetAppDataUseCase = resetAppDataUseCase
        self.configureVoticeUseCase = configureVoticeUseCase
        self.attachmentMigrationUseCase = attachmentMigrationUseCase
        self.remoteConfigManager = remoteConfigManager
        self.currentVersion = currentVersion
        self.launchDelay = launchDelay
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            configureVotice()
            attachmentMigrationUseCase.execute()

            let isCompleted = checkOnboardingUseCase.execute()
            if !isCompleted {
                resetAppDataUseCase.execute()
            }

            startLaunch(isOnboardingCompleted: isCompleted)
        case .onboardingCompleted:
            state = .home
        }
    }

    // MARK: - Private functions

    func configureVotice() {
        do {
            try configureVoticeUseCase.execute(userIsPremium: false)
        } catch {
            LogManager.error("LaunchViewModel: configureVoticeUseCase: execute: error: \(error)")
        }
    }

    func startLaunch(isOnboardingCompleted: Bool) {
        Task { [weak self, launchDelay] in
            guard let self else { return }

            async let launchDelayCompleted: Void = Self.waitForLaunchDelay(launchDelay)
            let remoteConfig = await loadRemoteConfig()
            await launchDelayCompleted
            finishLaunch(remoteConfig: remoteConfig, isOnboardingCompleted: isOnboardingCompleted)
        }
    }

    func loadRemoteConfig() async -> RemoteConfig? {
        do {
            let config = try await remoteConfigManager.loadConfig()
            LogManager.info("LaunchViewModel: Remote Config loaded")
            return config
        } catch {
            LogManager.error("LaunchViewModel: Remote Config load failed: \(error)")
            return nil
        }
    }

    func finishLaunch(remoteConfig: RemoteConfig?, isOnboardingCompleted: Bool) {
        if remoteConfig?.maintenanceMode.enabled == true {
            state = .maintenance
        } else if let update = requiredUpdate(from: remoteConfig) {
            state = .forceUpdate(update)
        } else {
            state = isOnboardingCompleted ? .home : .onboarding
        }
    }

    func requiredUpdate(from remoteConfig: RemoteConfig?) -> RemoteConfig.PlatformUpdate? {
        guard let remoteConfig, let currentVersion else { return nil }

#if os(iOS)
        let update = remoteConfig.appUpdate.ios
#else
        let update = remoteConfig.appUpdate.macos
#endif

        guard update.enabled, update.forceUpdate else { return nil }
        guard currentVersion.compare(update.latestVersion, options: .numeric) == .orderedAscending else { return nil }
        return update
    }

    nonisolated static func waitForLaunchDelay(_ launchDelay: Duration) async {
        guard launchDelay > .zero else { return }
        try? await Task.sleep(for: launchDelay)
    }
}
