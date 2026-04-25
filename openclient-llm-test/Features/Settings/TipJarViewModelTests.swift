//
//  TipJarViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TipJarViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: TipJarViewModel!
    private var mockUseCase: MockPurchaseTipUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockUseCase = MockPurchaseTipUseCase()
        sut = TipJarViewModel(purchaseTipUseCase: mockUseCase)
    }

    override func tearDown() async throws {
        sut = nil
        mockUseCase = nil
        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_withEmptyProducts_loadsEmptyState() async {
        // Given
        mockUseCase.productsResult = .success([])

        // When
        sut.send(.viewAppeared)
        await Task.yield()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.products.isEmpty)
        XCTAssertFalse(loadedState.isPurchasing)
        XCTAssertFalse(loadedState.showThankYou)
    }

    func test_send_viewAppeared_withProducts_loadsProducts() async {
        // Given
        let products = makeTipProducts()
        mockUseCase.productsResult = .success(products)

        // When
        sut.send(.viewAppeared)
        await Task.yield()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.products.count, 2)
        XCTAssertEqual(loadedState.products.first?.id, "com.artcc.openclient.tip.small")
    }

    func test_send_viewAppeared_onFetchError_setsErrorState() async {
        // Given
        mockUseCase.productsResult = .failure(NSError(domain: "test", code: -1))

        // When
        sut.send(.viewAppeared)
        await Task.yield()

        // Then
        guard case .error = sut.state else {
            XCTFail("Expected error state")
            return
        }
    }

    // MARK: - Tests — tipTapped

    func test_send_tipTapped_onSuccess_showsThankYou() async {
        // Given
        let products = makeTipProducts()
        mockUseCase.productsResult = .success(products)
        mockUseCase.purchaseResult = .success(.success)
        sut.send(.viewAppeared)
        await Task.yield()

        // When
        sut.send(.tipTapped(id: "com.artcc.openclient.tip.small"))
        await Task.yield()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.showThankYou)
        XCTAssertFalse(loadedState.isPurchasing)
        XCTAssertEqual(mockUseCase.purchasedProductId, "com.artcc.openclient.tip.small")
    }

    func test_send_tipTapped_onCancelled_doesNotShowThankYou() async {
        // Given
        let products = makeTipProducts()
        mockUseCase.productsResult = .success(products)
        mockUseCase.purchaseResult = .success(.cancelled)
        sut.send(.viewAppeared)
        await Task.yield()

        // When
        sut.send(.tipTapped(id: "com.artcc.openclient.tip.small"))
        await Task.yield()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showThankYou)
        XCTAssertFalse(loadedState.isPurchasing)
    }

    func test_send_tipTapped_onPurchaseError_clearsIsPurchasing() async {
        // Given
        let products = makeTipProducts()
        mockUseCase.productsResult = .success(products)
        mockUseCase.purchaseResult = .failure(NSError(domain: "StoreKit", code: -1))
        sut.send(.viewAppeared)
        await Task.yield()

        // When
        sut.send(.tipTapped(id: "com.artcc.openclient.tip.small"))
        await Task.yield()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isPurchasing)
        XCTAssertFalse(loadedState.showThankYou)
    }

    // MARK: - Tests — thankYouDismissed

    func test_send_thankYouDismissed_hidesThankYou() async {
        // Given
        let products = makeTipProducts()
        mockUseCase.productsResult = .success(products)
        mockUseCase.purchaseResult = .success(.success)
        sut.send(.viewAppeared)
        await Task.yield()
        sut.send(.tipTapped(id: "com.artcc.openclient.tip.small"))
        await Task.yield()

        // When
        sut.send(.thankYouDismissed)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showThankYou)
    }
}

// MARK: - Helpers

private extension TipJarViewModelTests {
    func makeTipProducts() -> [TipProduct] {
        [
            TipProduct(
                id: "com.artcc.openclient.tip.small",
                displayName: "Small Tip",
                displayPrice: "$0.99",
                price: 0.99
            ),
            TipProduct(
                id: "com.artcc.openclient.tip.medium",
                displayName: "Medium Tip",
                displayPrice: "$2.99",
                price: 2.99
            )
        ]
    }
}
