import Foundation
import ActivityKit

// MARK: - LiveActivityService
/// Manages the lifecycle of Richard's Live Activity (Dynamic Island).
/// Animates the pixel-art character by toggling frameIndex via a Timer,
/// causing the Widget to swap between frame PNG assets (e.g., normal1 ↔ normal2).
@MainActor
final class LiveActivityService {

    // MARK: - Singleton
    static let shared = LiveActivityService()
    private init() {}

    // MARK: - State
    private var currentActivity: Activity<RichardActivityAttributes>?
    private var animationTimer: Timer?
    private var currentFrame: Int = 0
    private var currentState: RichardState = .idle

    // MARK: - Public API

    /// Starts (or restarts) Richard's Live Activity and begins frame animation.
    func start(with state: RichardState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities not authorized on this device.")
            return
        }

        // If already running, just update state + reset animation
        if currentActivity != nil {
            update(to: state)
            return
        }

        currentState = state
        currentFrame = 0

        let attributes   = RichardActivityAttributes()
        let contentState = makeContentState(for: state, frame: currentFrame)

        do {
            let activity = try Activity<RichardActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started. ID: \(activity.id)")
            startAnimationTimer(for: state)
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    /// Updates Richard's state and resets animation to match new state's FPS.
    func update(to state: RichardState) {
        guard let activity = currentActivity else {
            start(with: state)
            return
        }

        // FPS가 달라지는 경우(상태 전환) 타이머 리셋
        if state != currentState {
            currentState = state
            currentFrame = 0
            restartAnimationTimer(for: state)
        }

        let newContent = makeContentState(for: state, frame: currentFrame)
        Task {
            await activity.update(.init(state: newContent, staleDate: nil))
            print("[LiveActivity] Updated to: \(state.displayName) frame:\(currentFrame)")
        }
    }

    /// Ends the Live Activity and stops animation.
    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil

        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Stopped.")
        }
    }

    // MARK: - Animation Timer

    private func startAnimationTimer(for state: RichardState) {
        animationTimer?.invalidate()

        let interval = 1.0 / state.animationFPS  // normal=0.5s, snack=1.0s
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            // 메인 스레드에서 실행 보장
            Task { @MainActor in
                self.advanceFrame()
            }
        }
        print("[LiveActivity] Animation timer started: \(state.animationFPS)fps (\(interval)s interval)")
    }

    private func restartAnimationTimer(for state: RichardState) {
        startAnimationTimer(for: state)
    }

    private func advanceFrame() {
        guard let activity = currentActivity else { return }
        currentFrame = (currentFrame + 1) % 2  // 0 ↔ 1 토글

        let newContent = makeContentState(for: currentState, frame: currentFrame)
        Task {
            await activity.update(.init(state: newContent, staleDate: nil))
        }
    }

    // MARK: - Helpers

    private func makeContentState(
        for state: RichardState,
        frame: Int
    ) -> RichardActivityAttributes.ContentState {
        RichardActivityAttributes.ContentState(
            state:         state,
            stateLabel:    state.displayName,
            faceImageName: state.faceImageName,
            shortText:     state.shortText,
            frameIndex:    frame
        )
    }
}
