//
//  MockPurchaseTipUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockPurchaseTipUseCase: PurchaseTipUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var productsResult: Result<[TipProduct], Error> = .success([])
    var purchaseResult: Result<TipPurchaseResult, Error> = .success(.success)
    var purchasedProductId: String?

    // MARK: - PurchaseTipUseCaseProtocol

    func fetchProducts() async throws -> [TipProduct] {
        try productsResult.get()
    }

    func purchase(productId: String) async throws -> TipPurchaseResult {
        purchasedProductId = productId
        return try purchaseResult.get()
    }
}
