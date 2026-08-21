//
//  ScrollTriggerModifier.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

enum ChatScrollAnchor: Hashable {
    case top
    case bottom
}

struct ScrollTriggerModifier: ViewModifier {
    @Binding var scrollToMessageId: UUID?
    @Binding var scrollState: ChatScrollState

    let proxy: ScrollViewProxy
    let snapshot: ChatScrollState.Snapshot
    let renderedMessageRevision: Int

    func body(content: Content) -> some View {
        content
            .onChange(of: snapshot, initial: true) { previousSnapshot, snapshot in
                let isInitial = previousSnapshot == snapshot
                let startsResponse = previousSnapshot.sessionId != snapshot.sessionId
                    || previousSnapshot.responseRevision != snapshot.responseRevision
                if !isInitial, !startsResponse, !scrollState.isFollowingBottom { return }
                guard scrollState.update(from: isInitial ? nil : previousSnapshot, to: snapshot) else { return }
                scrollToBottom()
            }
            .onChange(of: renderedMessageRevision) {
                guard scrollState.isFollowingBottom else { return }
                scrollToBottom()
            }
            .onChange(of: scrollToMessageId) { _, newId in
                guard let id = newId else { return }
                scrollState.detach()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(id)
                }
                scrollToMessageId = nil
            }
    }

    private func scrollToBottom() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(ChatScrollAnchor.bottom, anchor: .bottom)
        }
    }
}
