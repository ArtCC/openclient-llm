//
//  PurchaseTipUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol PurchaseTipUseCaseProtocol: Sendable {
    func fetchProducts() async throws -> [TipProduct]
    func purchase(productId: String) async throws -> TipPurchaseResult
}

struct PurchaseTipUseCase: PurchaseTipUseCaseProtocol {
    // MARK: - Properties

    private let tipJarManager: TipJarManagerProtocol

    // MARK: - Init

    init(tipJarManager: TipJarManagerProtocol = TipJarManager()) {
        self.tipJarManager = tipJarManager
    }

    // MARK: - PurchaseTipUseCaseProtocol

    func fetchProducts() async throws -> [TipProduct] {
        try await tipJarManager.fetchProducts()
    }

    func purchase(productId: String) async throws -> TipPurchaseResult {
        try await tipJarManager.purchase(productId: productId)
    }
}
