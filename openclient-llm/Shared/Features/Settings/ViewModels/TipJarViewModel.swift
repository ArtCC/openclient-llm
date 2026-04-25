//
//  TipJarViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class TipJarViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case tipTapped(id: String)
        case thankYouDismissed
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.loaded(let lhsState), .loaded(let rhsState)):
                return lhsState == rhsState
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }

    struct LoadedState: Equatable {
        var products: [TipProduct]
        var isPurchasing: Bool
        var showThankYou: Bool

        static func == (lhs: LoadedState, rhs: LoadedState) -> Bool {
            lhs.products.map(\.id) == rhs.products.map(\.id)
                && lhs.isPurchasing == rhs.isPurchasing
                && lhs.showThankYou == rhs.showThankYou
        }
    }

    private(set) var state: State

    private let purchaseTipUseCase: PurchaseTipUseCaseProtocol

    // MARK: - Init

    init(
        purchaseTipUseCase: PurchaseTipUseCaseProtocol = PurchaseTipUseCase(),
        state: State = .loading
    ) {
        self.purchaseTipUseCase = purchaseTipUseCase
        self.state = state
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadProducts()
        case .tipTapped(let id):
            purchase(productId: id)
        case .thankYouDismissed:
            guard case .loaded(var loadedState) = state else { return }
            loadedState.showThankYou = false
            state = .loaded(loadedState)
        }
    }
}

// MARK: - Private

private extension TipJarViewModel {
    func loadProducts() {
        Task {
            do {
                let products = try await purchaseTipUseCase.fetchProducts()
                state = .loaded(LoadedState(products: products, isPurchasing: false, showThankYou: false))
            } catch {
                LogManager.error("TipJarViewModel fetchProducts error: \(error)")
                state = .error(String(localized: "Could not load tip options. Please try again later."))
            }
        }
    }

    func purchase(productId: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isPurchasing = true
        state = .loaded(loadedState)

        Task {
            do {
                let result = try await purchaseTipUseCase.purchase(productId: productId)
                guard case .loaded(var currentState) = state else { return }
                currentState.isPurchasing = false
                if result == .success {
                    currentState.showThankYou = true
                }
                state = .loaded(currentState)
            } catch {
                LogManager.error("TipJarViewModel purchase error: \(error)")
                guard case .loaded(var currentState) = state else { return }
                currentState.isPurchasing = false
                state = .loaded(currentState)
            }
        }
    }
}
