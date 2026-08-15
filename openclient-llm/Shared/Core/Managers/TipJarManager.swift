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
    func restorePurchases() async throws
}

enum TipPurchaseResult: Sendable, Equatable {
    case success
    case cancelled
    case pending
}

struct TipProduct: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case oneTimeTip
        case monthlySubscription
        case annualSubscription
    }

    let id: String
    let displayName: String
    let displayPrice: String
    let price: Decimal
    let kind: Kind
}

// Safety: Stateless struct — all StoreKit calls use async/await.
struct TipJarManager: TipJarManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum ProductID {
        static let small = "com.artcc.openclient.tip.small"
        static let medium = "com.artcc.openclient.tip.medium"
        static let large = "com.artcc.openclient.tip.large"
        static let monthlySupport = "com.artcc.openclient.support.monthly"
        static let annualSupport = "com.artcc.openclient.support.annual"

        static var all: [String] { [small, medium, large, monthlySupport, annualSupport] }

        static func kind(for productID: String) -> TipProduct.Kind? {
            switch productID {
            case small, medium, large:
                .oneTimeTip
            case monthlySupport:
                .monthlySubscription
            case annualSupport:
                .annualSubscription
            default:
                nil
            }
        }
    }

    // MARK: - TipJarManagerProtocol

    func fetchProducts() async throws -> [TipProduct] {
        LogManager.network("TipJarManager → fetchProducts")
        let skProducts = try await Product.products(for: ProductID.all)
        let sorted = skProducts.sorted { $0.price < $1.price }
        LogManager.success("TipJarManager products=\(sorted.count)")
        return sorted.compactMap {
            guard let kind = ProductID.kind(for: $0.id) else { return nil }
            return TipProduct(
                id: $0.id,
                displayName: $0.displayName,
                displayPrice: $0.displayPrice,
                price: $0.price,
                kind: kind
            )
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

    func restorePurchases() async throws {
        LogManager.info("TipJarManager → restorePurchases")
        try await AppStore.sync()
    }
}
