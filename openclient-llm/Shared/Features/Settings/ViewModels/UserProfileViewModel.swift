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
        case nameChanged(String)
        case descriptionChanged(String)
        case extraInfoChanged(String)
        case saveTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var name: String = ""
        var profileDescription: String = ""
        var extraInfo: String = ""
    }

    private(set) var state: State
    private var originalProfile: UserProfile = UserProfile()

    private let userProfileManager: UserProfileManagerProtocol

    var hasChanges: Bool {
        guard case .loaded(let loadedState) = state else { return false }
        return loadedState.name != originalProfile.name
            || loadedState.profileDescription != originalProfile.profileDescription
            || loadedState.extraInfo != originalProfile.extraInfo
    }

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
        case .nameChanged(let name):
            updateName(name)
        case .descriptionChanged(let description):
            updateDescription(description)
        case .extraInfoChanged(let info):
            updateExtraInfo(info)
        case .saveTapped:
            saveProfile()
        }
    }
}

// MARK: - Private

private extension UserProfileViewModel {
    func loadProfile() {
        let profile = userProfileManager.getProfile()
        originalProfile = profile
        state = .loaded(LoadedState(
            name: profile.name,
            profileDescription: profile.profileDescription,
            extraInfo: profile.extraInfo
        ))
    }

    func updateName(_ name: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.name = String(name.prefix(50))
        state = .loaded(loadedState)
    }

    func updateDescription(_ description: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.profileDescription = String(description.prefix(200))
        state = .loaded(loadedState)
    }

    func updateExtraInfo(_ info: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.extraInfo = String(info.prefix(500))
        state = .loaded(loadedState)
    }

    func saveProfile() {
        guard case .loaded(let loadedState) = state else { return }
        let profile = UserProfile(
            name: loadedState.name,
            profileDescription: loadedState.profileDescription,
            extraInfo: loadedState.extraInfo
        )
        userProfileManager.saveProfile(profile)
        originalProfile = profile
    }
}
