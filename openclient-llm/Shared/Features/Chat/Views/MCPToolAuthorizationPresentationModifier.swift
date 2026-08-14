//
//  MCPToolAuthorizationPresentationModifier.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MCPToolAuthorizationPresentationModifier: ViewModifier {
    let viewModel: ChatViewModel
    let compact: Bool
    let isEnabled: Bool

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!(isEnabled && compact && pendingBatch != nil))
            .accessibilityHidden(isEnabled && compact && pendingBatch != nil)
            .overlay {
                if isEnabled, compact, let batch = pendingBatch {
                    compactAuthorization(batch)
                }
            }
            .sheet(isPresented: sheetBinding) {
                if let batch = viewModel.mcpAuthorizationCoordinator.pendingBatch {
                    sheetAuthorization(batch)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
#if os(iOS)
                if newPhase == .background,
                   viewModel.mcpAuthorizationCoordinator.pendingBatch != nil {
                    viewModel.send(.stopStreamingTapped)
                }
#endif
            }
    }
}

extension View {
    func mcpToolAuthorizationPresentation(
        viewModel: ChatViewModel,
        compact: Bool,
        isEnabled: Bool = true
    ) -> some View {
        modifier(MCPToolAuthorizationPresentationModifier(
            viewModel: viewModel,
            compact: compact,
            isEnabled: isEnabled
        ))
    }
}

private extension MCPToolAuthorizationPresentationModifier {
    var pendingBatch: MCPToolAuthorizationBatch? {
        viewModel.mcpAuthorizationCoordinator.pendingBatch
    }

    var sheetBinding: Binding<Bool> {
        Binding(
            get: { isEnabled && !compact && pendingBatch != nil },
            set: { _ in }
        )
    }

    func compactAuthorization(_ batch: MCPToolAuthorizationBatch) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            authorizationView(batch, compact: true)
                .background(.regularMaterial)
                .clipShape(.rect(cornerRadius: 16))
                .padding(10)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    func authorizationView(_ batch: MCPToolAuthorizationBatch, compact: Bool) -> some View {
        MCPToolAuthorizationView(
            batch: batch,
            compact: compact,
            submissionError: viewModel.mcpAuthorizationCoordinator.submissionError,
            conflictedPermissionKeys: viewModel.mcpAuthorizationCoordinator.conflictedPermissionKeys,
            onDecision: { requestId, decision in
                viewModel.send(.mcpAuthorizationDecision(
                    batchId: batch.id,
                    requestId: requestId,
                    decision: decision
                ))
            },
            onSubmit: { viewModel.send(.mcpAuthorizationSubmitted(batchId: batch.id)) },
            onDismiss: { viewModel.send(.mcpAuthorizationDismissed(batchId: batch.id)) },
            onStop: { viewModel.send(.stopStreamingTapped) }
        )
    }

    @ViewBuilder
    func sheetAuthorization(_ batch: MCPToolAuthorizationBatch) -> some View {
        authorizationView(batch, compact: false)
            .interactiveDismissDisabled()
#if os(macOS)
            .frame(minWidth: 560, maxWidth: 560, minHeight: 620, maxHeight: 620)
#else
            .presentationDetents([.medium])
#endif
    }
}
