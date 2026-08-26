//
//  MaintenanceView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MaintenanceView: View {
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
                    Text(String(localized: "OpenClient is under maintenance"))
                        .font(.title3.weight(.semibold))

                    Text(String(localized: "We're making a few improvements. Please try again later."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 420)
            .padding(32)
        }
        .transition(.opacity)
    }
}

#Preview {
    MaintenanceView()
}
