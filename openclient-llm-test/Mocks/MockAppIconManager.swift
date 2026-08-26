//
//  MockAppIconManager.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

@testable import openclient_llm

@MainActor
final class MockAppIconManager: AppIconManagerProtocol {
    var supportsAlternateIcons = true
    var selectedIcon: AppIcon = .defaultIcon
    var setIconResult: Result<Void, Error> = .success(())
    private(set) var setIconCalls: [AppIcon] = []

    func setIcon(_ icon: AppIcon) async throws {
        setIconCalls.append(icon)
        try setIconResult.get()
        selectedIcon = icon
    }
}
