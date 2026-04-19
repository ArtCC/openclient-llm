//
//  ScrollTriggerModifier.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import SwiftUI
#endif

struct ScrollTriggerModifier: ViewModifier {
    let loadedState: ChatViewModel.LoadedState
    @Binding var scrollPosition: ScrollPosition
    @Binding var isScrollThrottled: Bool
    @Binding var scrollToMessageId: UUID?
    @Binding var shouldAutoScroll: Bool
    let isNearBottom: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: loadedState.messages.count) {
                guard isNearBottom else { return }
                shouldAutoScroll = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollPosition.scrollTo(edge: .bottom)
                }
            }
            .onChange(of: loadedState.messages.last?.content) {
                guard shouldAutoScroll, !isScrollThrottled else { return }
                isScrollThrottled = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    scrollPosition.scrollTo(edge: .bottom)
                    isScrollThrottled = false
                }
            }
            .onChange(of: scrollToMessageId) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollPosition.scrollTo(id: id)
                }
                scrollToMessageId = nil
            }
            .task(id: loadedState.conversation?.id) {
                guard !loadedState.messages.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                scrollPosition.scrollTo(edge: .bottom)
            }
#if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { notification in
                let duration = notification.userInfo?[
                    UIResponder.keyboardAnimationDurationUserInfoKey
                ] as? Double ?? 0.25
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(duration))
                    scrollPosition.scrollTo(edge: .bottom)
                    shouldAutoScroll = true
                }
            }
#endif
    }
}
