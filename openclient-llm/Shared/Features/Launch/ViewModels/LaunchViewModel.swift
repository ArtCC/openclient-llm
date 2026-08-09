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
        case availableUpdateDismissed
        case remoteBannerDismissed
    }

    enum State: Equatable {
        case loading
        case onboarding
        case home
        case maintenance
        case forceUpdate(RemoteConfig.PlatformUpdate)
    }

    private(set) var state: State
    private(set) var availableUpdate: RemoteConfig.PlatformUpdate?
    private(set) var remoteBanner: RemoteBanner?

    private let checkOnboardingUseCase: CheckOnboardingUseCaseProtocol
    private let resetAppDataUseCase: ResetAppDataUseCaseProtocol
    private let configureVoticeUseCase: ConfigureVoticeUseCaseProtocol
    private let attachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol
    private let remoteConfigManager: RemoteConfigManagerProtocol
    private let settingsManager: SettingsManagerProtocol
    private let currentVersion: String?
    private let localeIdentifier: String
    private let launchDelay: Duration

    // MARK: - Init

    init(
        state: State = .loading,
        checkOnboardingUseCase: CheckOnboardingUseCaseProtocol = CheckOnboardingUseCase(),
        resetAppDataUseCase: ResetAppDataUseCaseProtocol = ResetAppDataUseCase(),
        configureVoticeUseCase: ConfigureVoticeUseCaseProtocol = ConfigureVoticeUseCase(),
        attachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol = AttachmentMigrationUseCase(),
        remoteConfigManager: RemoteConfigManagerProtocol = RemoteConfigManager(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        currentVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        localeIdentifier: String = Locale.current.identifier,
        launchDelay: Duration = .milliseconds(1000)
    ) {
        self.state = state
        self.checkOnboardingUseCase = checkOnboardingUseCase
        self.resetAppDataUseCase = resetAppDataUseCase
        self.configureVoticeUseCase = configureVoticeUseCase
        self.attachmentMigrationUseCase = attachmentMigrationUseCase
        self.remoteConfigManager = remoteConfigManager
        self.settingsManager = settingsManager
        self.currentVersion = currentVersion
        self.localeIdentifier = localeIdentifier
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
        case .availableUpdateDismissed:
            availableUpdate = nil
        case .remoteBannerDismissed:
            guard let remoteBanner else { return }
            settingsManager.setDismissedRemoteBannerKey(remoteBanner.id)
            self.remoteBanner = nil
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
        availableUpdate = nil
        remoteBanner = nil
        let update = availableUpdate(from: remoteConfig)

        if remoteConfig?.maintenanceMode.enabled == true {
            state = .maintenance
        } else if let update, update.forceUpdate {
            state = .forceUpdate(update)
        } else {
            availableUpdate = update
            remoteBanner = availableBanner(from: remoteConfig)
            state = isOnboardingCompleted ? .home : .onboarding
        }
    }

    func availableUpdate(from remoteConfig: RemoteConfig?) -> RemoteConfig.PlatformUpdate? {
        guard let remoteConfig, let currentVersion else { return nil }

#if os(iOS)
        let update = remoteConfig.appUpdate.ios
#else
        let update = remoteConfig.appUpdate.macos
#endif

        guard update.enabled else { return nil }
        guard currentVersion.compare(update.latestVersion, options: .numeric) == .orderedAscending else { return nil }
        return update
    }

    func availableBanner(from remoteConfig: RemoteConfig?) -> RemoteBanner? {
        guard let banner = remoteConfig?.banner, banner.active else { return nil }

#if os(iOS)
        let platform = RemoteConfig.Platform.ios
#else
        let platform = RemoteConfig.Platform.macos
#endif

        guard banner.platforms.contains(platform) else { return nil }
        guard settingsManager.getDismissedRemoteBannerKey() != banner.dismissBannerKey else { return nil }
        guard let item = localizedBannerItem(from: banner.items) else { return nil }
        return RemoteBanner(id: banner.dismissBannerKey, item: item)
    }

    func localizedBannerItem(from items: [String: RemoteConfig.Item]) -> RemoteConfig.Item? {
        let baseIdentifier = localeIdentifier
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init) ?? localeIdentifier
        let normalizedIdentifier = baseIdentifier.replacingOccurrences(of: "_", with: "-")
        let languageCode = normalizedIdentifier.split(separator: "-").first.map(String.init)
        let candidates = [normalizedIdentifier, languageCode, "en"].compactMap { $0 }

        for candidate in candidates {
            if let item = items.first(where: { $0.key.caseInsensitiveCompare(candidate) == .orderedSame })?.value {
                return item
            }
        }
        return nil
    }

    nonisolated static func waitForLaunchDelay(_ launchDelay: Duration) async {
        guard launchDelay > .zero else { return }
        try? await Task.sleep(for: launchDelay)
    }
}
