//
//  ChatContextUsageView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatContextUsageView: View {
    let usage: ContextUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { usageText }
                usageText
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            ProgressView(value: Double(usage.percentage), total: 100)
                .tint(tint)
                .controlSize(.mini)
            if usage.compactedMessageCount > 0 || usage.excludedMessageCount > 0 || usage.isLatestTurnOverBudget {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(usage.isLatestTurnOverBudget ? .red : .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Estimated context"))
        .accessibilityValue(accessibilityValue)
    }
}

private extension ChatContextUsageView {
    @ViewBuilder
    var usageText: some View {
        Text(String(localized: "Estimated context"))
        Text(usage.formattedUsage)
        Text("·")
        Text("\(usage.percentage)%")
    }

    var statusText: String {
        if usage.isLatestTurnOverBudget {
            return String(localized: "The latest turn exceeds the available context")
        }
        if usage.compactedMessageCount > 0 && usage.excludedMessageCount > 0 {
            return String(
                localized: "\(usage.compactedMessageCount) compacted · \(usage.excludedMessageCount) excluded"
            )
        }
        if usage.compactedMessageCount > 0 {
            return String(localized: "\(usage.compactedMessageCount) messages compacted")
        }
        return String(localized: "\(usage.excludedMessageCount) messages excluded from this request")
    }

    var accessibilityValue: String {
        var value = String(localized: "\(usage.formattedUsage) tokens, \(usage.percentage) percent")
        if usage.compactedMessageCount > 0 || usage.excludedMessageCount > 0 || usage.isLatestTurnOverBudget {
            value += ". \(statusText)"
        }
        return value
    }

    var tint: Color {
        switch usage.percentage {
        case 90...: .red
        case 70...: .orange
        default: Color.appAccent
        }
    }
}

#Preview {
    ChatContextUsageView(
        usage: ContextUsage(
            estimatedInputTokens: 7_200,
            maxInputTokens: 8_192,
            excludedMessageCount: 2,
            compactedMessageCount: 14
        )
    )
    .padding()
}
