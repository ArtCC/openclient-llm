//
//  ImageGenerationView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ImageGenerationView: View {
    // MARK: - Properties

    @State private var viewModel = ImageGenerationViewModel()
    @State private var promptText: String = ""

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let loadedState):
                    loadedView(loadedState)
                }
            }
            .navigationTitle(String(localized: "Image Generation"))
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ImageGenerationView {
    func loadedView(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        VStack(spacing: 0) {
            imageGallery(loadedState)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        errorBanner(loadedState.errorMessage)
                        configBar(loadedState)
                        inputBar(loadedState)
                    }
                }
        }
    }

    // MARK: - Gallery

    func imageGallery(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        ScrollView {
            if loadedState.generatedImages.isEmpty {
                emptyState
            } else {
                imageGrid(loadedState)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.artframe")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text(String(localized: "Generate Images"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "Describe the image you want to create"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    func imageGrid(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(loadedState.generatedImages) { image in
                imageCard(image)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func imageCard(_ image: GeneratedImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            generatedImageView(image)

            VStack(alignment: .leading, spacing: 4) {
                Text(image.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let revisedPrompt = image.revisedPrompt {
                    Text(revisedPrompt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Text(image.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .contextMenu {
            imageContextMenu(image)
        }
    }

    @ViewBuilder
    func generatedImageView(_ image: GeneratedImage) -> some View {
        #if os(iOS)
        if let uiImage = UIImage(data: image.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: image.imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
        }
        #endif
    }

    @ViewBuilder
    func imageContextMenu(_ image: GeneratedImage) -> some View {
        #if os(iOS)
        if let uiImage = UIImage(data: image.imageData) {
            ShareLink(
                item: Image(uiImage: uiImage),
                preview: SharePreview(image.prompt, image: Image(uiImage: uiImage))
            ) {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
            }

            Button {
                UIPasteboard.general.image = uiImage
            } label: {
                Label(String(localized: "Copy Image"), systemImage: "doc.on.doc")
            }
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: image.imageData) {
            ShareLink(
                item: Image(nsImage: nsImage),
                preview: SharePreview(image.prompt, image: Image(nsImage: nsImage))
            ) {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
            }

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([nsImage])
            } label: {
                Label(String(localized: "Copy Image"), systemImage: "doc.on.doc")
            }
        }
        #endif
    }

    // MARK: - Error Banner

    @ViewBuilder
    func errorBanner(_ errorMessage: String?) -> some View {
        if let errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(errorMessage)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.85))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Config Bar

    func configBar(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        HStack(spacing: 12) {
            modelPicker(loadedState)
            sizePicker(loadedState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func modelPicker(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        Menu {
            ForEach(loadedState.availableModels) { model in
                Button {
                    viewModel.send(.modelSelected(model.id))
                } label: {
                    HStack {
                        Text(model.id)
                        if model.id == loadedState.selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption)
                Text(loadedState.selectedModel.isEmpty
                     ? String(localized: "Select Model")
                     : loadedState.selectedModel)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    func sizePicker(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        Menu {
            ForEach(ImageGenerationViewModel.availableSizes, id: \.self) { size in
                Button {
                    viewModel.send(.sizeSelected(size))
                } label: {
                    HStack {
                        Text(size)
                        if size == loadedState.selectedSize {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "aspectratio")
                    .font(.caption)
                Text(loadedState.selectedSize)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    func inputBar(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        HStack(spacing: 8) {
            TextField(
                String(localized: "Describe the image..."),
                text: $promptText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            #if os(iOS)
            .submitLabel(.send)
            #endif
            .onSubmit {
                viewModel.send(.generateTapped)
            }
            .onChange(of: promptText) { _, newValue in
                viewModel.send(.promptChanged(newValue))
            }
            .onChange(of: loadedState.prompt) { _, newValue in
                if newValue != promptText {
                    promptText = newValue
                }
            }

            generateButton(loadedState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    func generateButton(_ loadedState: ImageGenerationViewModel.LoadedState) -> some View {
        if loadedState.isGenerating {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 44, minHeight: 44)
        } else {
            let hasPrompt = !loadedState.prompt
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            let hasModel = !loadedState.selectedModel.isEmpty

            if hasPrompt && hasModel {
                Button {
                    viewModel.send(.generateTapped)
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Generate"))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ImageGenerationView()
}
