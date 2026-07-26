//
//  ChatView+MCP.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension ChatView {
    func mcpToolsSheet() -> some View {
        MCPToolsSheet(viewModel: viewModel, isPresented: $showMCPSheet)
            #if os(macOS)
            .frame(minWidth: 500, maxWidth: 500, minHeight: 460, maxHeight: 460)
            #endif
    }
}
