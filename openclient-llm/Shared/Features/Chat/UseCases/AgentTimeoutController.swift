//
//  AgentTimeoutController.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor AgentTimeoutController {
    // MARK: - Properties

    private let clock = ContinuousClock()
    private var remaining: Duration
    private var startedAt: ContinuousClock.Instant?
    private var sleeper: Task<Void, Never>?
    private var onTimeout: (@Sendable () -> Void)?
    private var generation = 0
    private var isPaused = false
    private var isCancelled = false

    // MARK: - Init

    init(timeout: Duration) {
        self.remaining = timeout
    }

    // MARK: - Control

    func start(onTimeout: @escaping @Sendable () -> Void) {
        guard !isCancelled else { return }
        self.onTimeout = onTimeout
        if !isPaused { schedule() }
    }

    func pause() {
        guard !isCancelled, !isPaused else { return }
        updateRemainingTime()
        isPaused = true
        generation += 1
        sleeper?.cancel()
        sleeper = nil
    }

    func resume() {
        guard !isCancelled, isPaused else { return }
        isPaused = false
        schedule()
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        generation += 1
        sleeper?.cancel()
        sleeper = nil
        startedAt = nil
        onTimeout = nil
    }
}

actor AgentExecutionController {
    private var task: Task<Void, Never>?
    private var isCancelled = false

    func register(_ task: Task<Void, Never>) {
        if isCancelled {
            task.cancel()
        } else {
            self.task = task
        }
    }

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }
}

private extension AgentTimeoutController {
    func schedule() {
        guard onTimeout != nil else { return }
        guard remaining > .zero else {
            expire(generation: generation)
            return
        }
        generation += 1
        let currentGeneration = generation
        let delay = remaining
        startedAt = clock.now
        sleeper?.cancel()
        sleeper = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            await self?.expire(generation: currentGeneration)
        }
    }

    func updateRemainingTime() {
        guard let startedAt else { return }
        let elapsed = startedAt.duration(to: clock.now)
        remaining = max(.zero, remaining - elapsed)
        self.startedAt = nil
    }

    func expire(generation: Int) {
        guard !isCancelled, !isPaused, generation == self.generation else { return }
        remaining = .zero
        startedAt = nil
        sleeper = nil
        let action = onTimeout
        onTimeout = nil
        action?()
    }
}
