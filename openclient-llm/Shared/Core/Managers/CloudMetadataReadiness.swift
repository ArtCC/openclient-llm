//
//  CloudMetadataReadiness.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// Safety: `readySession` is read and written only while `lock` is held. The lock is immutable.
nonisolated final class CloudMetadataReadiness: @unchecked Sendable {
    static let shared = CloudMetadataReadiness()

    private let lock = NSLock()
    private var readySession: CloudSyncSession?

    func isReady(for session: CloudSyncSession) -> Bool {
        lock.withLock { readySession == session }
    }

    func setReady(for session: CloudSyncSession) {
        lock.withLock { readySession = session }
    }

    func reset() {
        lock.withLock { readySession = nil }
    }

    func reset(for session: CloudSyncSession) {
        lock.withLock {
            guard readySession == session else { return }
            readySession = nil
        }
    }
}
