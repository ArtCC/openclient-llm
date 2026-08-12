//
//  TestAsyncGate.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor TestAsyncGate {
    // MARK: - Properties

    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Public

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pendingWaiters = waiters
        waiters = []
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }
}
