//
//  EphemeralChatViewModelTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class EphemeralChatViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: EphemeralChatViewModel!
    private var mockFetchModels: MockFetchModelsUseCase!
    private var mockStreamMessage: MockStreamMessageUseCase!
    private var mockAgentStream: MockAgentStreamUseCase!
    private var mockWebSearch: MockWebSearchUseCase!
    private var mockPreferences: MockGetChatPreferencesUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockFetchModels = MockFetchModelsUseCase()
        mockStreamMessage = MockStreamMessageUseCase()
        mockAgentStream = MockAgentStreamUseCase()
        mockWebSearch = MockWebSearchUseCase()
        mockPreferences = MockGetChatPreferencesUseCase()
        sut = EphemeralChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgentStream,
            webSearchUseCase: mockWebSearch,
            getChatPreferencesUseCase: mockPreferences
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFetchModels = nil
        mockStreamMessage = nil
        mockAgentStream = nil
        mockWebSearch = nil
        mockPreferences = nil
        try await super.tearDown()
    }

    // MARK: - Tests - Attachments

    func test_send_attachmentAdded_keepsDataOnlyInMemory() async throws {
        // Given
        try await loadModel()
        let data = Data("private image".utf8)

        // When
        sut.send(.attachmentAdded(data: data, fileName: "private.jpg", type: .image))

        // Then
        let state = try loadedState()
        let attachment = try XCTUnwrap(state.pendingAttachments.first)
        XCTAssertEqual(attachment.transientData, data)
        XCTAssertTrue(attachment.fileRelativePath.isEmpty)
    }

    func test_send_viewDisappeared_discardsMessagesAndAttachments() async throws {
        // Given
        try await loadModel()
        sut.send(.attachmentAdded(data: Data("private".utf8), fileName: "private.pdf", type: .pdf))
        sut.send(.inputChanged("Do not retain this"))
        sut.send(.sendTapped)

        // When
        sut.send(.viewDisappeared)

        // Then
        let state = try loadedState()
        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertTrue(state.pendingAttachments.isEmpty)
    }

    // MARK: - Tests - Agent

    func test_send_sendTapped_withAgentDisabled_usesRegularStreaming() async throws {
        // Given
        let model = LLMModel(id: "agent", capabilities: [.functionCalling])
        try await loadModel(model)
        sut.send(.inputChanged("Do not run tools"))
        let execution = expectation(description: "Regular stream starts")
        mockStreamMessage.onExecute = { execution.fulfill() }

        // When
        sut.send(.sendTapped)
        await fulfillment(of: [execution], timeout: 1)

        // Then
        XCTAssertTrue(mockAgentStream.receivedToolNames.isEmpty)
        XCTAssertEqual(mockStreamMessage.receivedMessages.count, 1)
    }

    func test_send_webSearchToggled_withoutAgentOrFunctionCalling_keepsSearchDisabled() async throws {
        // Given
        mockPreferences.webSearchToolName = "web_search"
        try await loadModel()

        // When
        sut.send(.webSearchToggled)

        // Then
        XCTAssertFalse(try loadedState().isWebSearchEnabled)
    }

    func test_send_sendTapped_withFunctionCallingModel_excludesMemoryTools() async throws {
        // Given
        let model = LLMModel(id: "agent", capabilities: [.functionCalling])
        try await loadModel(model)
        sut.send(.inputChanged("What time is it?"))
        let execution = expectation(description: "Agent starts")
        mockAgentStream.onExecute = { execution.fulfill() }

        // When
        sut.send(.agentToggled)
        sut.send(.sendTapped)
        await fulfillment(of: [execution], timeout: 1)

        // Then
        XCTAssertTrue(mockAgentStream.receivedToolNames.contains("get_current_datetime"))
        XCTAssertFalse(mockAgentStream.receivedToolNames.contains("save_memory"))
        XCTAssertFalse(mockAgentStream.receivedToolNames.contains("delete_memory"))
    }

    func test_send_sendTapped_withWebSearchEnabled_registersWebSearchTool() async throws {
        // Given
        let model = LLMModel(id: "agent", capabilities: [.functionCalling])
        mockPreferences.webSearchToolName = "web_search"
        try await loadModel(model)
        sut.send(.inputChanged("Find current Swift news"))
        let execution = expectation(description: "Agent starts")
        mockAgentStream.onExecute = { execution.fulfill() }

        // When
        sut.send(.agentToggled)
        sut.send(.webSearchToggled)
        sut.send(.sendTapped)
        await fulfillment(of: [execution], timeout: 1)

        // Then
        XCTAssertTrue(mockAgentStream.receivedToolNames.contains("web_search"))
    }

    // MARK: - Private

    private func loadModel(_ model: LLMModel = LLMModel(id: "chat")) async throws {
        mockFetchModels.result = .success([model])
        let execution = expectation(description: "Models load")
        mockFetchModels.onExecute = { execution.fulfill() }
        sut.send(.viewAppeared)
        await fulfillment(of: [execution], timeout: 1)
    }

    private func loadedState() throws -> EphemeralChatViewModel.LoadedState {
        guard case .loaded(let state) = sut.state else {
            throw XCTSkip("Expected loaded state")
        }
        return state
    }
}
