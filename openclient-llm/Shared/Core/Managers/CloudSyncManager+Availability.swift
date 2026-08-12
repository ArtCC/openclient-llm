//
//  CloudSyncManager+Availability.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func isCloudAvailable() -> Bool {
        containerProvider.isAvailable() && cloudDocumentsDirectory() != nil
    }

    func checkCloudAvailability() async -> Bool {
        (try? await fileCoordinator.perform {
            containerProvider.isAvailable() && containerProvider.containerURL() != nil
        }) ?? false
    }
}
