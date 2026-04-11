# Architecture

OpenClient follows **MVVM + UseCase + Repository + Manager** with Swift strict concurrency and `async/await`.

```
View → ViewModel → UseCase → Repository → APIClient / LocalStorage
                      ↑
                   Manager (transversal services)
```

## Project Structure

```
openclient-llm/                              # iOS target
├── App/
│   ├── AppDelegate.swift                    # iOS UIKit delegate — registers SceneDelegate, sets dynamic shortcuts
│   ├── OpenClientApp.swift                  # iOS app entry point
│   └── SceneDelegate.swift                  # UIWindowSceneDelegate — quick action routing (cold + background launch)
├── Shared/                                  # Shared code (iOS + macOS)
│   ├── Features/
│   │   ├── AudioTranscription/
│   │   │   ├── Models/
│   │   │   │   └── Transcription.swift
│   │   │   ├── Repositories/
│   │   │   │   ├── AppleAudioTranscriptionRepository.swift
│   │   │   │   └── AudioTranscriptionRepository.swift
│   │   │   └── UseCases/
│   │   │       └── TranscribeAudioUseCase.swift
│   │   ├── Chat/
│   │   │   ├── Models/
│   │   │   │   ├── ChatMessage.swift
│   │   │   │   ├── ChatTool.swift
│   │   │   │   ├── Conversation.swift
│   │   │   │   ├── ConversationSection.swift
│   │   │   │   ├── ModelParameters.swift
│   │   │   │   ├── TokenUsage.swift
│   │   │   │   ├── ToolRegistry.swift
│   │   │   │   └── WebSearchTool.swift
│   │   │   ├── Repositories/
│   │   │   │   ├── ChatRepository.swift
│   │   │   │   └── ConversationRepository.swift
│   │   │   ├── UseCases/
│   │   │   │   ├── AgentStreamUseCase.swift
│   │   │   │   ├── BranchConversationUseCase.swift
│   │   │   │   ├── DeleteConversationUseCase.swift
│   │   │   │   ├── ExportConversationUseCase.swift
│   │   │   │   ├── LoadConversationsUseCase.swift
│   │   │   │   ├── PinConversationUseCase.swift
│   │   │   │   ├── SaveConversationUseCase.swift
│   │   │   │   ├── SendMessageUseCase.swift
│   │   │   │   ├── StreamMessageUseCase.swift
│   │   │   │   ├── UpdateConversationTagsUseCase.swift
│   │   │   │   └── WebSearchUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   ├── ChatViewModel.swift
│   │   │   │   ├── ChatViewModel+Agent.swift
│   │   │   │   ├── ChatViewModel+EditExport.swift
│   │   │   │   ├── ChatViewModel+Helpers.swift
│   │   │   │   ├── ChatViewModel+Streaming.swift
│   │   │   │   ├── ChatViewModel+Transcription.swift
│   │   │   │   ├── ChatViewModel+WebSearch.swift
│   │   │   │   └── ConversationListViewModel.swift
│   │   │   └── Views/
│   │   │       ├── AttachmentPickerView.swift
│   │   │       ├── CameraPickerView.swift
│   │   │       ├── ChatEmptyStateView.swift
│   │   │       ├── ChatFavouritesView.swift          # Sheet listing favourited messages; tap → scroll to message
│   │   │       ├── ChatInputBarView.swift
│   │   │       ├── ChatModelParametersView.swift
│   │   │       ├── ChatSystemPromptView.swift
│   │   │       ├── ChatView.swift
│   │   │       ├── ChatView+Attachments.swift        # errorBanner, attachmentPreview, attachmentThumbnail helpers
│   │   │       ├── ChatView+EditExport.swift
│   │   │       ├── ChatView+Menu.swift                # ChatMenuAction enum + menuActions(for:) sorted by localizedCompare
│   │   │       ├── ChatView+ModelSelector.swift
│   │   │       ├── CodeBlockView.swift
│   │   │       ├── ConversationListView.swift
│   │   │       ├── ConversationTagsView.swift
│   │   │       ├── ImagePreviewView.swift
│   │   │       ├── MediaFilesGalleryView.swift        # Sheet with image grid + document list; PDFPreviewView included
│   │   │       ├── MessageBubbleView.swift
│   │   │       ├── MessageBubbleView+Previews.swift   # #Preview blocks extracted from MessageBubbleView
│   │   │       ├── SearchConversationsView.swift
│   │   │       └── WebSearchSourcesView.swift
│   │   ├── Home/
│   │   │   ├── UseCases/
│   │   │   │   └── GetSelectedModelUseCase.swift  # Returns selected model ID via SettingsManagerProtocol
│   │   │   ├── ViewModels/
│   │   │   │   └── HomeViewModel.swift            # Event/State: newChatShortcutTriggered, spotlightConversationRequested
│   │   │   └── Views/
│   │   │       └── HomeView.swift                 # iOS TabView (AppTab enum + symbol animations) + macOS NavigationSplitView
│   │   ├── Launch/
│   │   │   ├── UseCases/
│   │   │   │   ├── CheckOnboardingUseCase.swift
│   │   │   │   ├── ConfigureVoticeUseCase.swift
│   │   │   │   └── ResetAppDataUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── LaunchViewModel.swift
│   │   │   └── Views/
│   │   │       └── LaunchView.swift
│   │   ├── Models/
│   │   │   ├── Models/
│   │   │   │   └── LLMModel.swift
│   │   │   ├── Repositories/
│   │   │   │   └── ModelsRepository.swift
│   │   │   ├── UseCases/
│   │   │   │   └── FetchModelsUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── ModelsViewModel.swift
│   │   │   └── Views/
│   │   │       └── ModelsView.swift
│   │   ├── Onboarding/
│   │   │   ├── Models/
│   │   │   │   └── OnboardingStep.swift
│   │   │   ├── Repositories/
│   │   │   │   └── OnboardingRepository.swift
│   │   │   ├── UseCases/
│   │   │   │   ├── CompleteOnboardingUseCase.swift
│   │   │   │   ├── SaveServerConfigurationUseCase.swift
│   │   │   │   └── TestServerConnectionUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── OnboardingViewModel.swift
│   │   │   └── Views/
│   │   │       └── OnboardingView.swift
│   │   ├── PromptTemplates/
│   │   │   ├── Models/
│   │   │   │   └── PromptTemplate.swift
│   │   │   ├── Repositories/
│   │   │   │   └── PromptTemplateRepository.swift
│   │   │   ├── UseCases/
│   │   │   │   ├── DeletePromptTemplateUseCase.swift
│   │   │   │   ├── LoadPromptTemplatesUseCase.swift
│   │   │   │   └── SavePromptTemplateUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── PromptTemplatesViewModel.swift
│   │   │   └── Views/
│   │   │       ├── PromptTemplateEditorView.swift
│   │   │       └── PromptTemplatesView.swift
│   │   ├── Settings/
│   │   │   ├── Models/
│   │   │   │   └── UserProfile.swift
│   │   │   ├── ViewModels/
│   │   │   │   ├── SettingsViewModel.swift
│   │   │   │   └── UserProfileViewModel.swift
│   │   │   └── Views/
│   │   │       ├── SettingsView.swift
│   │   │       └── UserProfileView.swift
│   │   └── TextToSpeech/
│   │       ├── Models/
│   │       │   └── TTSVoice.swift
│   │       ├── Repositories/
│   │       │   └── TextToSpeechRepository.swift
│   │       └── UseCases/
│   │           └── SynthesizeSpeechUseCase.swift
│   ├── Core/
│   │   ├── Extensions/
│   │   │   ├── Foundation/
│   │   │   │   └── Notification.Name.swift
│   │   │   └── SwiftUI/
│   │   │       ├── Color.swift
│   │   │       └── Font.swift
│   │   ├── Managers/
│   │   │   ├── AppleSpeechRecognitionManager.swift
│   │   │   ├── AudioPlayerManager.swift
│   │   │   ├── AudioRecorderManager.swift
│   │   │   ├── CloudSyncManager.swift
│   │   │   ├── ConversationStartersManager.swift
│   │   │   ├── HapticManager.swift
│   │   │   ├── KeychainManager.swift
│   │   │   ├── LogManager.swift
│   │   │   ├── SettingsManager.swift
│   │   │   ├── ShortcutManager.swift
│   │   │   ├── SpotlightManager.swift
│   │   │   ├── UserProfileManager.swift
│   │   │   └── VoticeManager.swift
│   │   ├── Networking/
│   │   │   ├── APIClient.swift
│   │   │   ├── APIError.swift
│   │   │   └── Models/
│   │   │       ├── AudioTranscriptionRequest.swift
│   │   │       ├── AudioTranscriptionResponse.swift
│   │   │       ├── ChatCompletionRequest.swift
│   │   │       ├── ChatCompletionResponse.swift
│   │   │       ├── ChatCompletionStreamResponse.swift
│   │   │       ├── ModelInfoResponse.swift
│   │   │       ├── ModelsResponse.swift
│   │   │       ├── OllamaShowResponse.swift
│   │   │       ├── SearchModels.swift
│   │   │       ├── TextToSpeechRequest.swift
│   │   │       └── ToolModels.swift
│   │   ├── Utils/
│   │   │   ├── Constants.swift
│   │   │   ├── MarkdownParser.swift
│   │   │   ├── PoppinsFont.swift
│   │   │   └── SpotlightConstants.swift            # activityType + activityIdentifierKey (CSSearchableItem constants)
│   │   └── Views/
│   │       ├── FlowLayout.swift
│   │       └── WebContentView.swift
│   └── Resources/
│       └── Localizable.xcstrings
└── Resources/
    ├── Info.plist
    ├── openclient-llm.entitlements
    ├── openclient-llm.xctestplan
    └── Assets.xcassets/

openclient-llm-macOS/                        # macOS target
├── App/
│   ├── AppDelegate.swift                    # NSApplicationDelegate — sets up MenuBarManager on launch
│   └── OpenClientApp.swift                  # macOS app entry point; @NSApplicationDelegateAdaptor(AppDelegate.self)
├── Views/
│   ├── AppCommands.swift                    # macOS menu commands (⌘N New Chat)
│   ├── MenuBarChatView.swift                # Popover content: full ChatView + "Open in App" header button
│   └── MenuBarManager.swift                 # NSStatusItem + NSPopover lifecycle; toggles on status bar icon tap
└── Resources/
    ├── Info.plist
    ├── openclient-llm-macOS.entitlements
    └── Assets.xcassets/

openclient-llm-test/                         # Unit tests
├── Core/
│   └── Managers/
│       ├── KeychainManagerTests.swift
│       ├── SettingsManagerSTTTests.swift
│       └── SettingsManagerTTSTests.swift
├── Features/
│   ├── Home/
│   │   └── HomeViewModelTests.swift
│   ├── Chat/
│   │   ├── AgentStreamUseCaseTests.swift
│   │   ├── BranchConversationUseCaseTests.swift
│   │   ├── ChatViewModelTests.swift
│   │   ├── ChatViewModelTests+Agent.swift
│   │   ├── ChatViewModelTests+Branching.swift
│   │   ├── ChatViewModelTests+Editing.swift
│   │   ├── ChatViewModelTests+Export.swift
│   │   ├── ChatViewModelTests+Persistence.swift
│   │   ├── ChatViewModelTests+Reasoning.swift
│   │   ├── ChatViewModelTests+Regenerate.swift
│   │   ├── ChatViewModelTests+TTS.swift
│   │   ├── ChatViewModelTests+Transcription.swift
│   │   ├── ChatViewModelTests+UserProfile.swift
│   │   ├── ChatViewModelTests+WebSearch.swift
│   │   ├── ConversationListViewModelTests.swift
│   │   ├── ConversationListViewModelTests+Pinning.swift
│   │   ├── ConversationListViewModelTests+Tags.swift
│   │   ├── ConversationSectionTests.swift
│   │   ├── ExportConversationUseCaseTests.swift
│   │   ├── SendMessageUseCaseTests.swift
│   │   ├── StreamMessageUseCaseTests.swift
│   │   └── WebSearchUseCaseTests.swift
│   ├── Launch/
│   │   ├── CheckOnboardingUseCaseTests.swift
│   │   ├── LaunchViewModelTests.swift
│   │   └── ResetAppDataUseCaseTests.swift
│   ├── Models/
│   │   ├── FetchModelsUseCaseTests.swift
│   │   ├── ModelsViewModelSTTTests.swift
│   │   ├── ModelsViewModelTTSTests.swift
│   │   └── ModelsViewModelTests.swift
│   ├── Onboarding/
│   │   ├── CompleteOnboardingUseCaseTests.swift
│   │   ├── OnboardingViewModelTests.swift
│   │   ├── SaveServerConfigurationUseCaseTests.swift
│   │   └── TestServerConnectionUseCaseTests.swift
│   ├── PromptTemplates/
│   │   └── PromptTemplatesViewModelTests.swift
│   └── Settings/
│       ├── SettingsViewModelTests.swift
│       ├── UserProfileTests.swift
│       └── UserProfileViewModelTests.swift
└── Mocks/
    ├── MockAPIClient.swift
    ├── MockAgentStreamUseCase.swift
    ├── MockAppleSpeechRecognitionManager.swift
    ├── MockAudioRecorderManager.swift
    ├── MockBranchConversationUseCase.swift
    ├── MockChatRepository.swift
    ├── MockCheckLiteLLMHealthUseCase.swift
    ├── MockCheckOnboardingUseCase.swift
    ├── MockCloudSyncManager.swift
    ├── MockCompleteOnboardingUseCase.swift
    ├── MockConversationRepository.swift
    ├── MockConversationStartersManager.swift
    ├── MockDeleteConversationUseCase.swift
    ├── MockDeletePromptTemplateUseCase.swift
    ├── MockExportConversationUseCase.swift
    ├── MockFetchModelsUseCase.swift
    ├── MockGetSelectedModelUseCase.swift
    ├── MockKeychainManager.swift
    ├── MockLoadConversationsUseCase.swift
    ├── MockLoadPromptTemplatesUseCase.swift
    ├── MockModelsRepository.swift
    ├── MockOnboardingRepository.swift
    ├── MockPinConversationUseCase.swift
    ├── MockPromptTemplateRepository.swift
    ├── MockResetAppDataUseCase.swift
    ├── MockSaveConversationUseCase.swift
    ├── MockSavePromptTemplateUseCase.swift
    ├── MockSaveServerConfigurationUseCase.swift
    ├── MockSettingsManager.swift
    ├── MockStreamMessageUseCase.swift
    ├── MockSynthesizeSpeechUseCase.swift
    ├── MockTestServerConnectionUseCase.swift
    ├── MockTranscribeAudioUseCase.swift
    ├── MockUpdateConversationTagsUseCase.swift
    ├── MockUserProfileManager.swift
    └── MockWebSearchUseCase.swift
```

## Layer Responsibilities

| Layer | Responsibility |
|---|---|
| **View** | SwiftUI views. Observes ViewModel state, sends events. No business logic. |
| **ViewModel** | `@Observable @MainActor`. Event/State pattern. Coordinates UseCases. |
| **UseCase** | Single business operation. Calls Repositories and Managers. |
| **Repository** | Data access abstraction (network, cache, local storage). Protocol-based for testability. |
| **Manager** | Transversal services shared across features (auth, settings, connectivity). |
| **APIClient** | Single networking layer via `URLSession` + `async/await`. Communicates with LiteLLM. |

## Platform Strategy

- **`Shared/`** — All business logic, models, networking, ViewModels, UseCases, Repositories, Managers. Referenced by both targets.
- **`openclient-llm/`** (outside Shared) — iOS/iPadOS-specific views, app entry point, iOS resources.
- **`openclient-llm-macOS/`** — macOS-specific views, app entry point, macOS resources. No shared logic duplicated here.
- **`#if os(iOS)` / `#if os(macOS)`** — Used inside shared views for platform-specific UI variations.