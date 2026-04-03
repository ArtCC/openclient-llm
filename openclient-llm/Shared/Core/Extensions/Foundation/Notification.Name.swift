//
//  Notification.Name.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension Notification.Name {
    /// Posted after the user confirms a full app data reset.
    /// ChatViewModel and ModelsViewModel observe this to reload their state.
    static let appDataDidReset = Notification.Name("openclient.appDataDidReset")
}
