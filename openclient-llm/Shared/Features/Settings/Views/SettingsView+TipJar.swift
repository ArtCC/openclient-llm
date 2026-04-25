//
//  SettingsView+TipJar.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Tip Jar

extension SettingsView {
    func tipJarSection(isPresented: Binding<Bool>) -> some View {
        Section {
            Button {
                isPresented.wrappedValue = true
            } label: {
                Label(String(localized: "Buy Me a Coffee"), systemImage: "cup.and.saucer")
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Buy Me a Coffee"))
        }
    }
}
