//
//  HorizontalRuleView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct HorizontalRuleView: View {
    // MARK: - View

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Above the rule")
        HorizontalRuleView()
        Text("Below the rule")
    }
    .padding()
}
