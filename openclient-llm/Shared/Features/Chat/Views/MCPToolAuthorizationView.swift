//
//  MCPToolAuthorizationView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MCPToolAuthorizationView: View {
    let batch: MCPToolAuthorizationBatch
    let compact: Bool
    let submissionError: String?
    let conflictedPermissionKeys: Set<String>
    let onDecision: (UUID, MCPToolAuthorizationDecision) -> Void
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    let onStop: () -> Void

    @State private var permanentRequest: PermanentPermissionRequest?
    @FocusState private var focusedRequestId: UUID?
    @AccessibilityFocusState private var isSubmissionErrorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        explanation
                        ForEach(batch.requests) { request in
                            requestCard(request)
                        }
                    }
                    .padding(16)
                }
                Divider()
                footer
            }
            .navigationTitle(String(localized: "MCP Approval Required"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { closeToolbar }
        }
        .alert(item: $permanentRequest) { request in
            permanentPermissionAlert(request)
        }
        .onAppear {
            focusedRequestId = batch.requests.first?.id
        }
        .onChange(of: submissionError) { _, error in
            isSubmissionErrorFocused = error != nil
        }
    }
}

private extension MCPToolAuthorizationView {
    struct PermanentPermissionRequest: Identifiable {
        let id = UUID()
        let requestId: UUID
        let toolName: String
        let decision: MCPToolAuthorizationDecision
    }

    var explanation: some View {
        Label {
            Text(String(localized: "Review each external tool before anything is executed."))
                .font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.shield")
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    func requestCard(_ request: MCPToolAuthorizationRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            requestHeader(request)
            if conflictedPermissionKeys.contains(request.metadata.permissionKey) {
                Label(
                    String(localized: "Settings changed. This call can now only be denied."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
            impactView(request)
            argumentsView(request)
            decisionControls(request)
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    func requestHeader(_ request: MCPToolAuthorizationRequest) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(request.metadata.displayName)
                .font(.headline)
            Text(request.displayToolName)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Label(request.metadata.serverName, systemImage: "server.rack")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let description = request.metadata.toolDescription {
                Text(String(localized: "Server-provided description: \(description)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func impactView(_ request: MCPToolAuthorizationRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(String(localized: "Potential Impact"), systemImage: "exclamationmark.shield")
                .font(.subheadline.weight(.semibold))
            Text(String(
                localized: """
                Sends the arguments below to \(request.metadata.serverName). It may access, create, change, or delete \
                external data and may incur costs.
                """
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    func argumentsView(_ request: MCPToolAuthorizationRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Arguments"))
                .font(.subheadline.weight(.semibold))
            ScrollView([.horizontal, .vertical]) {
                Text(request.formattedArguments)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: compact ? 110 : 180)
            .background(.black.opacity(0.06), in: .rect(cornerRadius: 8))
        }
    }

    func decisionControls(_ request: MCPToolAuthorizationRequest) -> some View {
        let selection = batch.decisions[request.id]
        let hasConflict = conflictedPermissionKeys.contains(request.metadata.permissionKey)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                decisionButton(
                    String(localized: "Deny Once"),
                    systemImage: "xmark",
                    selected: selection == .denyOnce,
                    tint: .red
                ) {
                    onDecision(request.id, .denyOnce)
                }
                .focused($focusedRequestId, equals: request.id)
                decisionButton(
                    String(localized: "Allow Once"),
                    systemImage: "checkmark",
                    selected: selection == .allowOnce,
                    tint: Color.appAccent
                ) {
                    onDecision(request.id, .allowOnce)
                }
                .disabled(hasConflict)
            }
            Menu {
                Button {
                    permanentRequest = PermanentPermissionRequest(
                        requestId: request.id,
                        toolName: request.metadata.displayName,
                        decision: .alwaysAllow
                    )
                } label: {
                    Label(String(localized: "Always Allow This Tool"), systemImage: "checkmark.shield")
                }
                .disabled(hasConflict)
                Button(role: .destructive) {
                    permanentRequest = PermanentPermissionRequest(
                        requestId: request.id,
                        toolName: request.metadata.displayName,
                        decision: .alwaysDeny
                    )
                } label: {
                    Label(String(localized: "Always Deny This Tool"), systemImage: "nosign")
                }
            } label: {
                Label(persistentSelectionTitle(selection), systemImage: "ellipsis.circle")
                    .font(.caption)
            }
            .disabled(hasConflict)
        }
    }

    func decisionButton(
        _ title: String,
        systemImage: String,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Label(title, systemImage: systemImage)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selected ? tint : .secondary)
        .accessibilityValue(selected ? String(localized: "Selected") : "")
    }

    func persistentSelectionTitle(_ selection: MCPToolAuthorizationDecision?) -> String {
        switch selection {
        case .alwaysAllow:
            String(localized: "Always Allow Selected")
        case .alwaysDeny:
            String(localized: "Always Deny Selected")
        default:
            String(localized: "More Options")
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let submissionError {
                Label(submissionError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityFocused($isSubmissionErrorFocused)
            }
            HStack(spacing: 10) {
                Button(role: .destructive, action: onStop) {
                    Text(String(localized: "Stop Response"))
                }
                    .buttonStyle(.bordered)
                Button(String(localized: "Continue"), action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!batch.isComplete || submissionError != nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
    }

    @ToolbarContentBuilder
    var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Deny All & Close"), action: onDismiss)
        }
    }

    func permanentPermissionAlert(_ request: PermanentPermissionRequest) -> Alert {
        let isAllowing = request.decision == .alwaysAllow
        let title = isAllowing
            ? String(localized: "Always Allow \(request.toolName)?")
            : String(localized: "Always Deny \(request.toolName)?")
        let message = isAllowing
            ? String(localized: """
                If you continue, future calls can execute without confirmation for this configuration.
                """)
            : String(localized: "If you continue, future calls will be blocked for this server configuration.")
        let confirmButton: Alert.Button
        if isAllowing {
            confirmButton = .default(Text(String(localized: "Confirm"))) {
                onDecision(request.requestId, request.decision)
            }
        } else {
            confirmButton = .destructive(Text(String(localized: "Confirm"))) {
                onDecision(request.requestId, request.decision)
            }
        }
        return Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: confirmButton,
            secondaryButton: .cancel()
        )
    }
}

#Preview("Conflict - Compact") {
    MCPToolAuthorizationView(
        batch: MCPToolAuthorizationBatch(
            id: UUID(),
            requests: [MCPToolAuthorizationRequest(
                id: UUID(),
                toolCallId: "call-1",
                toolName: "github-create_issue",
                arguments: #"{"repository":"artcc/openclient-llm","title":"Improve MCP permissions"}"#,
                metadata: MCPToolAuthorizationMetadata(
                    toolId: "github-create_issue",
                    displayName: "create_issue",
                    serverName: "GitHub",
                    toolDescription: "Create an issue in a repository",
                    permissionKey: "preview",
                    permission: .ask
                )
            )],
            decisions: [:]
        ),
        compact: true,
        submissionError: String(localized: "MCP tool settings changed. Affected allow decisions were cleared."),
        conflictedPermissionKeys: ["preview"],
        onDecision: { _, _ in },
        onSubmit: {},
        onDismiss: {},
        onStop: {}
    )
}
