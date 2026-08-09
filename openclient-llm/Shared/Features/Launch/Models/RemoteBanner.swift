//
//  RemoteBanner.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct RemoteBanner: Equatable, Identifiable, Sendable {
    let id: String
    let item: RemoteConfig.Item
}
