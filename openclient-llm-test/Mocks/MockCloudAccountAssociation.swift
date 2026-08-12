//
//  MockCloudAccountAssociation.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockCloudAccountAssociation: CloudAccountAssociationProtocol, @unchecked Sendable {
    var associationState: CloudAccountAssociationState = .matched
    var fingerprint: String? = "fingerprint"
    var approvalError: Error?
    var approveCallCount = 0

    func state() -> CloudAccountAssociationState {
        associationState
    }

    func currentAccountFingerprint() -> String? {
        fingerprint
    }

    func approveCurrentAccount(expectedFingerprint: String) throws {
        approveCallCount += 1
        if let approvalError { throw approvalError }
        guard expectedFingerprint == fingerprint else { throw CloudAccountAssociationError.accountChanged }
        associationState = .matched
    }
}
