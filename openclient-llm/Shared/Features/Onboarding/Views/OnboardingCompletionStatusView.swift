//
//  OnboardingCompletionStatusView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct OnboardingCompletionStatusView: View {
    let hasPersistenceError: Bool

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(statusColor.opacity(0.08))
                    .frame(width: 170, height: 170)
                Image(systemName: hasPersistenceError
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.bounce)
            }

            VStack(spacing: 10) {
                Text(hasPersistenceError
                    ? String(localized: "Server Configuration Wasn't Saved")
                    : String(localized: "You're all set!"))
                    .font(.poppins(.bold, size: 34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                Text(hasPersistenceError
                    ? String(localized: "Try starting the chat again to securely save your server settings.")
                    : String(localized: "Your server is ready. Let's start a conversation."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
}

private extension OnboardingCompletionStatusView {
    var statusColor: Color { hasPersistenceError ? .red : .green }
}

#Preview {
    OnboardingCompletionStatusView(hasPersistenceError: true)
        .padding()
}
