//
//  UserProfileViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class UserProfileViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case save(name: String, description: String, extraInfo: String)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var name: String = ""
        var profileDescription: String = ""
        var extraInfo: String = ""
        var originalName: String = ""
        var originalDescription: String = ""
        var originalExtraInfo: String = ""
    }

    private(set) var state: State

    private let userProfileManager: UserProfileManagerProtocol
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        userProfileManager: UserProfileManagerProtocol = UserProfileManager()
    ) {
        self.state = state
        self.userProfileManager = userProfileManager
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadProfile()
            startObservingCloudChanges()
        case .save(let name, let description, let extraInfo):
            saveProfile(name: name, description: description, extraInfo: extraInfo)
        }
    }
}

// MARK: - Private

private extension UserProfileViewModel {
    func startObservingCloudChanges() {
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: UserProfileManager.profileDidChangeExternallyNotification
            ) {
                guard let self, !Task.isCancelled else { break }
                self.loadProfile()
            }
        }
    }

    func loadProfile() {
        let profile = userProfileManager.getProfile()
        state = .loaded(LoadedState(
            name: profile.name,
            profileDescription: profile.profileDescription,
            extraInfo: profile.extraInfo,
            originalName: profile.name,
            originalDescription: profile.profileDescription,
            originalExtraInfo: profile.extraInfo
        ))
    }

    func saveProfile(name: String, description: String, extraInfo: String) {
        let profile = UserProfile(
            name: name,
            profileDescription: description,
            extraInfo: extraInfo
        )
        userProfileManager.saveProfile(profile)
        guard case .loaded(var loadedState) = state else { return }
        loadedState.name = name
        loadedState.profileDescription = description
        loadedState.extraInfo = extraInfo
        loadedState.originalName = name
        loadedState.originalDescription = description
        loadedState.originalExtraInfo = extraInfo
        state = .loaded(loadedState)
    }
}
