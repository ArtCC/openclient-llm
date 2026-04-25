//
//  TipJarView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import ConfettiSwiftUI
import SwiftUI

struct TipJarView: View {
    // MARK: - Properties

    @State private var viewModel = TipJarViewModel()
    @State private var confettiTrigger: Int = 0
    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let loadedState):
                    loadedView(loadedState)
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle(String(localized: "Buy Me a Coffee"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
        .confettiCannon(
            trigger: $confettiTrigger,
            confettis: [.text("☕"), .shape(.circle), .shape(.triangle), .shape(.square)],
            colors: [.brown, .orange, .yellow, .pink, .purple],
            repetitions: 2,
            repetitionInterval: 0.5
        )
        .onChange(of: showThankYou) { _, isShowing in
            if isShowing {
                confettiTrigger += 1
            }
        }
    }
}

// MARK: - Private

private extension TipJarView {
    var showThankYou: Bool {
        guard case .loaded(let loadedState) = viewModel.state else { return false }
        return loadedState.showThankYou
    }

    func loadedView(_ loadedState: TipJarViewModel.LoadedState) -> some View {
        ScrollView {
            VStack(spacing: 25) {
                Spacer()
                headerSection()
                tipsSection(loadedState)
                Spacer()
            }
            .padding()
        }
        .overlay {
            if loadedState.isPurchasing {
                purchasingOverlay()
            }
        }
        .alert(
            String(localized: "Thank you! ☕"),
            isPresented: thankYouBinding(loadedState)
        ) {
            Button(String(localized: "You're welcome!"), role: .cancel) {
                viewModel.send(.thankYouDismissed)
            }
        } message: {
            Text(String(localized: "Your support means a lot and helps keep the app free and open source."))
        }
    }

    func headerSection() -> some View {
        VStack(spacing: 20) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 125, height: 125)
                .cornerRadius(25)
                .shadow(color: .cyan.opacity(0.4), radius: 24, x: 0, y: 8)

            VStack(spacing: 15) {
                Text(String(localized: "OpenClient is free and open source"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(tipBodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "One-time purchase · Doesn't unlock any features, everything is already free"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    func tipsSection(_ loadedState: TipJarViewModel.LoadedState) -> some View {
        let products = loadedState.products
        let isPurchasing = loadedState.isPurchasing
        return VStack(spacing: 12) {
            if products.count >= 3 {
                coffeeCard(products[2], emoji: "☕☕☕", isFeatured: true, isPurchasing: isPurchasing)
                HStack(spacing: 12) {
                    coffeeCard(products[1], emoji: "☕☕", isFeatured: false, isPurchasing: isPurchasing)
                    coffeeCard(products[0], emoji: "☕", isFeatured: false, isPurchasing: isPurchasing)
                }
            } else {
                ForEach(products) { product in
                    coffeeCard(product, emoji: "☕", isFeatured: false, isPurchasing: isPurchasing)
                }
            }
        }
    }

    func coffeeCard(_ product: TipProduct, emoji: String, isFeatured: Bool, isPurchasing: Bool) -> some View {
        Button {
            viewModel.send(.tipTapped(id: product.id))
        } label: {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: isFeatured ? 40 : 28))
                Text(product.displayName)
                    .font(isFeatured ? .subheadline : .caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                Text(product.displayPrice)
                    .font(isFeatured ? .title2 : .callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.accent)
            }
            .padding(.vertical, isFeatured ? 24 : 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func purchasingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(String(localized: "Processing..."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    var tipBodyText: String {
        String(
            localized: "Buying me a coffee keeps development going!"
        )
    }

    func thankYouBinding(_ loadedState: TipJarViewModel.LoadedState) -> Binding<Bool> {
        Binding(
            get: { loadedState.showThankYou },
            set: { newValue in
                if !newValue {
                    viewModel.send(.thankYouDismissed)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    TipJarView()
}
