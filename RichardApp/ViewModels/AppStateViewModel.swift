import Foundation
import Combine

// MARK: - AppStateViewModel
/// The single source of truth for the entire app's state.
/// Injected as @EnvironmentObject into all views.
@MainActor
final class AppStateViewModel: ObservableObject {
    private let liveActivityPreviewState: RichardState = .test

    // MARK: Published State
    @Published var richardState: RichardState = .idle
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var userName: String = AppSettings.userName {
        didSet { AppSettings.userName = userName }
    }

    // MARK: Services
    private let llmService      = LLMService()
    private let autonomyService = AutonomyService()       // Phase 3: real-time timer
    private let liveActivity    = LiveActivityService.shared // Phase 3: Dynamic Island

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        // Set initial state from the timer-based service
        self.richardState = autonomyService.currentState

        // Subscribe: whenever AutonomyService ticks a new state, propagate it
        autonomyService.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                self.richardState = newState
                self.liveActivity.update(to: self.liveActivityPreviewState)
            }
            .store(in: &cancellables)

        // Keep Dynamic Island pinned to the preview sprite while testing assets.
        liveActivity.start(with: liveActivityPreviewState)
    }

    // MARK: - Public Intents

    /// Called when the user sends a chat message.
    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        chatMessages.append(userMessage)
        
        let currentStateStatic = richardState
        let userNameStatic = userName
        let history = chatMessages

        isLoading = true

        Task {
            do {
                let responseText = try await llmService.sendMessage(
                    history: history,
                    userInput: text,
                    currentState: currentStateStatic,
                    userName: userNameStatic
                )
                
                let lines = responseText.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                for (index, line) in lines.enumerated() {
                    await MainActor.run {
                        let richardMessage = ChatMessage(role: .richard, content: line)
                        self.chatMessages.append(richardMessage)
                        // 만약 다음 보낼 메시지가 남아있다면 다시 '타이핑 중...' 표시
                        self.isLoading = (index < lines.count - 1)
                    }
                    
                    if index < lines.count - 1 {
                        // 메시지 사이에 0.8초 딜레이를 주어 사람이 끊어서 치는 것처럼 구현
                        try? await Task.sleep(nanoseconds: 800_000_000)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error calling LLM: \(error)")
                }
            }
        }
    }

    /// Manual state override from a UI button tap.
    /// AutonomyService's next tick will revert to schedule automatically.
    func updateState(_ newState: RichardState) {
        autonomyService.overrideState(newState)
        // The Combine subscription above will pick it up and push to Live Activity.
    }
}
