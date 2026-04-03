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
│   └── OpenClientApp.swift                  # iOS app entry point
├── Shared/                                  # Shared code (iOS + macOS)
│   ├── Features/
│   │   ├── AudioTranscription/
│   │   │   ├── Models/
│   │   │   │   └── Transcription.swift
│   │   │   ├── Repositories/
│   │   │   │   └── AudioTranscriptionRepository.swift
│   │   │   └── UseCases/
│   │   │       └── TranscribeAudioUseCase.swift
│   │   ├── Chat/
│   │   │   ├── Models/
│   │   │   │   ├── ChatMessage.swift
│   │   │   │   ├── Conversation.swift
│   │   │   │   ├── ConversationSection.swift
│   │   │   │   ├── ModelParameters.swift
│   │   │   │   └── TokenUsage.swift
│   │   │   ├── Repositories/
│   │   │   │   ├── ChatRepository.swift
│   │   │   │   └── ConversationRepository.swift
│   │   │   ├── UseCases/
│   │   │   │   ├── DeleteConversationUseCase.swift
│   │   │   │   ├── LoadConversationsUseCase.swift
│   │   │   │   ├── PinConversationUseCase.swift
│   │   │   │   ├── SaveConversationUseCase.swift
│   │   │   │   ├── SendMessageUseCase.swift
│   │   │   │   ├── StreamMessageUseCase.swift
│   │   │   │   └── UpdateConversationTagsUseCase.swift
│   │   │   ├── ViewModels/
│   │   │   │   ├── ChatViewModel.swift
│   │   │   │   ├── ChatViewModel+Helpers.swift
│   │   │   │   ├── ChatViewModel+Transcription.swift
│   │   │   │   └── ConversationListViewModel.swift
│   │   │   └── Views/
│   │   │       ├── AttachmentPickerView.swift
│   │   │       ├── CameraPickerView.swift
│   │   │       ├── ChatEmptyStateView.swift
│   │   │       ├── ChatInputBarView.swift
│   │   │       ├── ChatModelParametersView.swift
│   │   │       ├── ChatSystemPromptView.swift
│   │   │       ├── ChatView.swift
│   │   │       ├── CodeBlockView.swift
│   │   │       ├── ConversationListView.swift
│   │   │       ├── ConversationTagsView.swift
│   │   │       ├── ImagePreviewView.swift
│   │   │       ├── MessageBubbleView.swift
│   │   │       └── SearchConversationsView.swift
│   │   ├── Home/
│   │   │   └── Views/
│   │   │       └── HomeView.swift             # iOS TabView (AppTab enum + symbol animations) + macOS NavigationSplitView
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
│   │       ├── Repositories/
│   │       │   └── TextToSpeechRepository.swift
│   │       └── UseCases/
│   │           └── SynthesizeSpeechUseCase.swift
│   ├── Core/
│   │   ├── Managers/
│   │   │   ├── AudioPlayerManager.swift
│   │   │   ├── AudioRecorderManager.swift
│   │   │   ├── CloudSyncManager.swift
│   │   │   ├── ConversationStartersManager.swift
│   │   │   ├── KeychainManager.swift
│   │   │   ├── LogManager.swift
│   │   │   ├── SettingsManager.swift
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
│   │   │       └── TextToSpeechRequest.swift
│   │   ├── Utils/
│   │   │   ├── Constants.swift
│   │   │   └── MarkdownParser.swift
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
│   └── OpenClientApp.swift                  # macOS app entry point
├── Views/
│   └── AppCommands.swift                    # macOS menu commands (⌘N New Chat)
└── Resources/
    ├── Info.plist
    ├── openclient-llm-macOS.entitlements
    └── Assets.xcassets/

openclient-llm-test/                         # Unit tests
├── Core/
│   └── Managers/
│       └── KeychainManagerTests.swift
├── Features/
│   ├── Chat/
│   │   ├── ChatViewModelTests.swift
│   │   ├── ChatViewModelTests+Persistence.swift
│   │   ├── ChatViewModelTests+TTS.swift
│   │   ├── ChatViewModelTests+Transcription.swift
│   │   ├── ChatViewModelTests+UserProfile.swift
│   │   ├── ConversationListViewModelTests.swift
│   │   ├── ConversationListViewModelTests+Pinning.swift
│   │   ├── ConversationListViewModelTests+Tags.swift
│   │   ├── ConversationSectionTests.swift
│   │   ├── SendMessageUseCaseTests.swift
│   │   └── StreamMessageUseCaseTests.swift
│   ├── Launch/
│   │   ├── CheckOnboardingUseCaseTests.swift
│   │   ├── LaunchViewModelTests.swift
│   │   └── ResetAppDataUseCaseTests.swift
│   ├── Models/
│   │   ├── FetchModelsUseCaseTests.swift
│   │   └── ModelsViewModelTests.swift
│   ├── Onboarding/
│   │   ├── CompleteOnboardingUseCaseTests.swift
│   │   ├── OnboardingViewModelTests.swift
│   │   ├── SaveServerConfigurationUseCaseTests.swift
│   │   └── TestServerConnectionUseCaseTests.swift
│   └── Settings/
│       ├── SettingsViewModelTests.swift
│       ├── UserProfileTests.swift
│       └── UserProfileViewModelTests.swift
└── Mocks/
    ├── MockAPIClient.swift
    ├── MockChatRepository.swift
    ├── MockCheckOnboardingUseCase.swift
    ├── MockCloudSyncManager.swift
    ├── MockCompleteOnboardingUseCase.swift
    ├── MockConversationRepository.swift
    ├── MockConversationStartersManager.swift
    ├── MockDeleteConversationUseCase.swift
    ├── MockFetchModelsUseCase.swift
    ├── MockKeychainManager.swift
    ├── MockLoadConversationsUseCase.swift
    ├── MockModelsRepository.swift
    ├── MockOnboardingRepository.swift
    ├── MockPinConversationUseCase.swift
    ├── MockResetAppDataUseCase.swift
    ├── MockSaveConversationUseCase.swift
    ├── MockSaveServerConfigurationUseCase.swift
    ├── MockSettingsManager.swift
    ├── MockStreamMessageUseCase.swift
    ├── MockSynthesizeSpeechUseCase.swift
    ├── MockTestServerConnectionUseCase.swift
    ├── MockTranscribeAudioUseCase.swift
    ├── MockUpdateConversationTagsUseCase.swift
    └── MockUserProfileManager.swift
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