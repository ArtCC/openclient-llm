//
//  TipJarManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import StoreKit

protocol TipJarManagerProtocol: Sendable {
    func fetchProducts() async throws -> [TipProduct]
    func purchase(productId: String) async throws -> TipPurchaseResult
}

enum TipPurchaseResult: Sendable, Equatable {
    case success
    case cancelled
    case pending
}

struct TipProduct: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let price: Decimal
}

// Safety: Stateless struct — all StoreKit calls use async/await.
struct TipJarManager: TipJarManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum ProductID {
        static let small = "com.artcc.openclient.tip.small"
        static let medium = "com.artcc.openclient.tip.medium"
        static let large = "com.artcc.openclient.tip.large"

        static var all: [String] { [small, medium, large] }
    }

    // MARK: - TipJarManagerProtocol

    func fetchProducts() async throws -> [TipProduct] {
        LogManager.network("TipJarManager → fetchProducts")
        let skProducts = try await Product.products(for: ProductID.all)
        let sorted = skProducts.sorted { $0.price < $1.price }
        LogManager.success("TipJarManager products=\(sorted.count)")
        return sorted.map {
            TipProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice, price: $0.price)
        }
    }

    func purchase(productId: String) async throws -> TipPurchaseResult {
        LogManager.info("TipJarManager → purchase \(productId)")
        let skProducts = try await Product.products(for: [productId])
        guard let skProduct = skProducts.first else {
            LogManager.error("TipJarManager product not found: \(productId)")
            return .cancelled
        }
        let result = try await skProduct.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return .success
            case .unverified:
                return .cancelled
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }
}
