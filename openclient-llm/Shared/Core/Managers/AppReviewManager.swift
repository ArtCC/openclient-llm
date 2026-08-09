//
//  AppReviewManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import StoreKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - AppReviewManagerProtocol

@MainActor
protocol AppReviewManagerProtocol {
    func requestReview()
}

// MARK: - AppReviewManager

@MainActor
struct AppReviewManager: AppReviewManagerProtocol {
    // MARK: - Public functions

    func requestReview() {
#if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            LogManager.warning("App review request skipped: no active window scene")
            return
        }
        AppStore.requestReview(in: scene)
#elseif os(macOS)
        guard let viewController = (NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow)?
            .contentViewController else {
            LogManager.warning("App review request skipped: no active view controller")
            return
        }
        AppStore.requestReview(in: viewController)
#endif
    }
}
