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
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)

                Text(String(localized: "OpenClient"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Private

private extension PrivacyScreenView {
    var appIcon: UIImage {
        let iconNames: [String] = ["AppIcon60x60", "AppIcon", "AppIcon-60@2x", "AppIcon-60@3x"]
        for name in iconNames {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return UIImage(systemName: "bubble.left.and.bubble.right.fill") ?? UIImage()
    }
}

#Preview {
    PrivacyScreenView()
}
#endif
