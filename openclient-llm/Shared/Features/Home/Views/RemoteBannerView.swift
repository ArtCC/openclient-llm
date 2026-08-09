//
//  RemoteBannerView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct RemoteBannerView: View {
    // MARK: - Properties

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    let banner: RemoteBanner
    let onDismiss: () -> Void
    let onAction: () -> Void

    // MARK: - View

    var body: some View {
        Group {
            if usesCompactLayout {
                compactContent
            } else {
                regularContent
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Private

private extension RemoteBannerView {
    var usesCompactLayout: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    var compactContent: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                emoji
                message
                closeButton
            }

            if !banner.item.cta.isEmpty {
                actionButton
            }
        }
    }

    var regularContent: some View {
        HStack(spacing: 14) {
            emoji
            message
            Spacer(minLength: 16)

            if !banner.item.cta.isEmpty {
                actionButton
            }
            closeButton
        }
    }

    var emoji: some View {
        Text(banner.item.emoji)
            .font(.title2)
            .accessibilityHidden(true)
    }

    var message: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(banner.item.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(banner.item.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var actionButton: some View {
        Button(banner.item.cta, action: onAction)
            .buttonStyle(.borderedProminent)
#if os(iOS)
            .frame(minHeight: 44)
#else
            .controlSize(.small)
#endif
    }

    var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
#if os(iOS)
                .frame(width: 44, height: 44)
#else
                .frame(width: 30, height: 30)
#endif
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Dismiss banner"))
    }
}

#Preview {
    RemoteBannerView(
        banner: RemoteBanner(
            id: "preview",
            item: .init(
                title: "OpenClient news",
                subtitle: "Important news, tips, and updates will appear here.",
                cta: "Learn more",
                action: .openURL,
                url: "https://example.com",
                emoji: "✨"
            )
        ),
        onDismiss: {},
        onAction: {}
    )
    .padding()
}
