//
//  PrivacyScreenView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

#if os(iOS)
import SwiftUI

struct PrivacyScreenView: View {
    // MARK: - View

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 125, height: 125)
                    .shadow(color: .cyan.opacity(0.4), radius: 24, x: 0, y: 8)
                    .cornerRadius(25)

                VStack(spacing: 4) {
                    Text(String(localized: "OpenClient"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(String(localized: "Your AI conversations"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    PrivacyScreenView()
}
#endif
