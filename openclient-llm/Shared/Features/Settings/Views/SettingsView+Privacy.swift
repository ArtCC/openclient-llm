//
//  SettingsView+Privacy.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

#if os(iOS)
import SwiftUI

// MARK: - Privacy

extension SettingsView {
    func privacySection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        let footerText = String(
            localized: "When enabled, app content is hidden when you switch to another app, similar to banking apps."
        )
        return Section {
            Toggle(isOn: Binding(
                get: { loadedState.isPrivacyScreenEnabled },
                set: { viewModel.send(.privacyScreenToggled($0)) }
            )) {
                Label(String(localized: "Hide Content in App Switcher"), systemImage: "lock.shield")
            }
        } header: {
            Text(String(localized: "Privacy"))
        } footer: {
            Text(footerText)
        }
    }
}
#endif
