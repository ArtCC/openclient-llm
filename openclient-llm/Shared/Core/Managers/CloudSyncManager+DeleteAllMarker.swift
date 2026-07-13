//
//  CloudSyncManager+DeleteAllMarker.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func loadConversationDeleteAllMarkerFromCloud() throws -> ConversationDeleteAllMarker? {
        guard let url = cloudDocumentsDirectory()?.appendingPathComponent("ConversationDeleteAll.json"),
              fileManager.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ConversationDeleteAllMarker.self, from: Data(contentsOf: url))
    }

    func saveConversationDeleteAllMarkerToCloud(_ marker: ConversationDeleteAllMarker) throws {
        guard let url = cloudDocumentsDirectory()?.appendingPathComponent("ConversationDeleteAll.json") else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try writeIfChanged(encoder.encode(marker), to: url)
    }
}
