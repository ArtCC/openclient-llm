//
//  ImageGenerationViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ImageGenerationViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case promptChanged(String)
        case modelSelected(String)
        case sizeSelected(String)
        case generateTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var prompt: String = ""
        var selectedModel: String = ""
        var selectedSize: String = "1024x1024"
        var availableModels: [LLMModel] = []
        var generatedImages: [GeneratedImage] = []
        var isGenerating: Bool = false
        var errorMessage: String?
    }

    static let availableSizes = ["256x256", "512x512", "1024x1024", "1024x1792", "1792x1024"]

    private(set) var state: State

    private let generateImageUseCase: GenerateImageUseCaseProtocol
    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private var errorDismissTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        generateImageUseCase: GenerateImageUseCaseProtocol = GenerateImageUseCase(),
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase()
    ) {
        self.state = state
        self.generateImageUseCase = generateImageUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadModels()
        case .promptChanged(let prompt):
            updatePrompt(prompt)
        case .modelSelected(let model):
            selectModel(model)
        case .sizeSelected(let size):
            selectSize(size)
        case .generateTapped:
            generateImage()
        }
    }
}

// MARK: - Private

private extension ImageGenerationViewModel {
    func loadModels() {
        state = .loading

        Task {
            do {
                let allModels = try await fetchModelsUseCase.execute()
                let models = allModels.filter { $0.mode == .imageGeneration }
                let defaultModel = models.first?.id ?? ""
                state = .loaded(LoadedState(
                    selectedModel: defaultModel,
                    availableModels: models
                ))
            } catch {
                state = .loaded(LoadedState(
                    errorMessage: error.localizedDescription
                ))
                scheduleErrorDismiss()
            }
        }
    }

    func updatePrompt(_ prompt: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.prompt = prompt
        state = .loaded(loadedState)
    }

    func selectModel(_ model: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedModel = model
        state = .loaded(loadedState)
    }

    func selectSize(_ size: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedSize = size
        state = .loaded(loadedState)
    }

    func generateImage() {
        guard case .loaded(var loadedState) = state else { return }
        let prompt = loadedState.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !loadedState.selectedModel.isEmpty, !loadedState.isGenerating else { return }

        loadedState.isGenerating = true
        loadedState.errorMessage = nil
        state = .loaded(loadedState)

        let model = loadedState.selectedModel
        let size = loadedState.selectedSize
        let mode: LLMModel.Mode = .imageGeneration

        Task {
            do {
                let image = try await generateImageUseCase.execute(
                    prompt: prompt,
                    model: model,
                    size: size,
                    mode: mode
                )

                guard case .loaded(var currentState) = state else { return }
                currentState.generatedImages.insert(image, at: 0)
                currentState.isGenerating = false
                currentState.prompt = ""
                state = .loaded(currentState)
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.isGenerating = false
                currentState.errorMessage = error.localizedDescription
                state = .loaded(currentState)
                scheduleErrorDismiss()
            }
        }
    }

    func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            currentState.errorMessage = nil
            state = .loaded(currentState)
        }
    }
}
