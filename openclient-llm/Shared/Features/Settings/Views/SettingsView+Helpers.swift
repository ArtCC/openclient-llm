//
//  SettingsView+Helpers.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if os(iOS)
import StoreKit
#endif

// MARK: - Helpers

extension SettingsView {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    func requestAppReview() {
#if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        AppStore.requestReview(in: windowScene)
#else
        if let url = URL(string: "macappstore://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review") {
            NSWorkspace.shared.open(url)
        }
#endif
    }
}
