//
//  HomeView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    // MARK: - View

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }
}

// MARK: - Private

private extension HomeView {
    #if os(iOS)
    var iOSLayout: some View {
        TabView {
            Tab(String(localized: "Chat"), systemImage: "bubble.left.and.bubble.right") {
                ChatView()
            }
            Tab(String(localized: "Models"), systemImage: "cpu") {
                ModelsView()
            }
            Tab(String(localized: "Settings"), systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
    #endif

    #if os(macOS)
    var macOSLayout: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    ChatView()
                } label: {
                    Label(String(localized: "Chat"), systemImage: "bubble.left.and.bubble.right")
                }

                NavigationLink {
                    ModelsView()
                } label: {
                    Label(String(localized: "Models"), systemImage: "cpu")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                }
            }
            .navigationTitle(String(localized: "OpenClient"))
        } detail: {
            ChatView()
        }
    }
    #endif
}

#Preview {
    HomeView()
}
