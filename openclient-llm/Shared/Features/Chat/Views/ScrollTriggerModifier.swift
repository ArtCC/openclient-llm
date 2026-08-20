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

private enum AutoScrollPriority: Int {
    case content
    case structural
    case keyboard
}

struct ScrollTriggerModifier: ViewModifier {
    @Binding var scrollPosition: ScrollPosition
    @Binding var scrollToMessageId: UUID?
    @Binding var shouldAutoScroll: Bool

    let loadedState: ChatViewModel.LoadedState

    @State private var autoScrollTask: Task<Void, Never>?
    @State private var pendingPriority: AutoScrollPriority?

    func body(content: Content) -> some View {
        content
            .onChange(of: loadedState.messages.count) {
                scheduleBottomScroll(
                    after: .zero,
                    animation: .easeInOut(duration: 0.25),
                    priority: .structural
                )
            }
            .onChange(of: scrollToMessageId) { _, newId in
                guard let id = newId else { return }
                cancelAutoScroll()
                shouldAutoScroll = false
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollPosition.scrollTo(id: id)
                }
                scrollToMessageId = nil
            }
            .onChange(of: shouldAutoScroll) { _, isEnabled in
                if !isEnabled { cancelAutoScroll() }
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentSize.height - $0.containerSize.height
            } action: { oldExtent, newExtent in
                guard oldExtent != newExtent else { return }
                scheduleBottomScroll(
                    after: .milliseconds(50),
                    animation: .linear(duration: 0.1)
                )
            }
            .task(id: loadedState.conversation?.id) {
                shouldAutoScroll = true
                guard !loadedState.messages.isEmpty else { return }
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
                scheduleBottomScroll(
                    after: .zero,
                    animation: .easeInOut(duration: 0.25),
                    priority: .structural
                )
            }
            .onDisappear(perform: cancelAutoScroll)
#if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { notification in
                let duration = notification.userInfo?[
                    UIResponder.keyboardAnimationDurationUserInfoKey
                ] as? Double ?? 0.25
                scheduleBottomScroll(
                    after: .seconds(duration),
                    animation: .easeInOut(duration: 0.25),
                    priority: .keyboard
                )
            }
#endif
    }

    private func scheduleBottomScroll(
        after delay: Duration,
        animation: Animation? = nil,
        priority: AutoScrollPriority = .content
    ) {
        guard shouldAutoScroll else { return }
        if let pendingPriority {
            guard priority.rawValue > pendingPriority.rawValue else { return }
            cancelAutoScroll()
        }
        pendingPriority = priority
        autoScrollTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard shouldAutoScroll, !Task.isCancelled else {
                autoScrollTask = nil
                pendingPriority = nil
                return
            }
            if let animation {
                withAnimation(animation) {
                    scrollPosition.scrollTo(edge: .bottom)
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollPosition.scrollTo(edge: .bottom)
                }
            }
            autoScrollTask = nil
            pendingPriority = nil
        }
    }

    private func cancelAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        pendingPriority = nil
    }
}
