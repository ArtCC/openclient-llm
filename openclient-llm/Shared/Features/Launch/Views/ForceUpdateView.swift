//
//  ForceUpdateView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ForceUpdateView: View {
    // MARK: - Properties

    @Environment(\.openURL) private var openURL

    let update: RemoteConfig.PlatformUpdate

    // MARK: - View

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                CurrentAppIconImage()
                    .scaledToFit()
                    .frame(width: 125, height: 125)
                    .shadow(color: .cyan.opacity(0.4), radius: 24, x: 0, y: 8)
                    .cornerRadius(25)

                VStack(spacing: 8) {
                    Text(String(localized: "Update required"))
                        .font(.title3.weight(.semibold))

                    Text(
                        String(
                            localized: "Update OpenClient to version \(update.latestVersion) to continue using the app."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                Button {
                    openURL(update.updateURL)
                } label: {
                    Label(String(localized: "Update OpenClient"), systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
            }
            .frame(maxWidth: 420)
            .padding(32)
        }
        .transition(.opacity)
    }
}

#Preview {
    ForceUpdateView(
        update: .init(
            enabled: true,
            forceUpdate: true,
            latestVersion: "2.0.0",
            updateURL: URL(string: "https://apps.apple.com/app/id6761379499") ?? URL(filePath: "/")
        )
    )
}
