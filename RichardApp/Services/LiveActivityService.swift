import Foundation
import ActivityKit

// MARK: - LiveActivityService
/// Manages the lifecycle of Richard's Live Activity (Dynamic Island).
/// Animates the pixel-art character by cycling frameIndex via a Timer,
/// causing the Widget to swap between frame PNG assets using animationFrames array.
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
    private var isInForeground: Bool = true
    // 이전 update Task가 아직 실행 중이면 건너뜀 (throttle 방지)
    private var isUpdating: Bool = false

    // MARK: - Public API

    /// Starts Richard's Live Activity (기존 stale activity 정리 후 새로 시작)
    func start(with state: RichardState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities not authorized on this device.")
            return
        }

        if currentActivity != nil {
            update(to: state)
            return
        }

        Task {
            for activity in Activity<RichardActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
                print("[LiveActivity] Cleaned up stale activity: \(activity.id)")
            }
            await MainActor.run {
                self.launchActivity(state: state)
            }
        }
    }

    /// Updates Richard's state and resets animation to match new state's frame sequence.
    func update(to state: RichardState) {
        guard let activity = currentActivity else {
            launchActivity(state: state)
            return
        }

        if state != currentState {
            currentState = state
            currentFrame = 0
            isUpdating = false // 상태 변경 시 락을 완전 초기화하여 굳는 현상 방지
            restartAnimationTimer()
        }

        pushUpdate(activity: activity, frame: currentFrame)
    }

    /// Ends the Live Activity and stops animation.
    func stop() {
        stopTimer()
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run { self.currentActivity = nil }
            print("[LiveActivity] Stopped.")
        }
    }

    /// 앱이 포그라운드로 돌아왔을 때 타이머를 재개합니다.
    func handleForeground() {
        guard !isInForeground else { return }
        isInForeground = true
        print("[LiveActivity] Foreground: restarting timer.")
        isUpdating = false // 포그라운드 진입 시 강제 락 해제
        restartAnimationTimer()
        // 즉시 현재 프레임 한 번 push해서 화면 갱신
        if let activity = currentActivity {
            pushUpdate(activity: activity, frame: currentFrame)
        }
    }

    /// 앱이 백그라운드로 진입할 때 타이머를 정지합니다.
    func handleBackground() {
        guard isInForeground else { return }
        isInForeground = false
        print("[LiveActivity] Background: pausing timer.")
        stopTimer()
    }

    // MARK: - Private

    private func launchActivity(state: RichardState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        currentState = state
        currentFrame = 0

        let attributes   = RichardActivityAttributes()
        let contentState = makeContentState(for: state, frame: 0)

        do {
            let activity = try Activity<RichardActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started. ID: \(activity.id)")
            restartAnimationTimer()
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    // MARK: - Timer

    private func restartAnimationTimer() {
        stopTimer()
        isUpdating = false // 타이머 리스타트 시점에도 혹시 모를 락을 완전히 해제하여 안전 장치 보장
        guard currentActivity != nil else { return }

        let interval = 1.0 / currentState.animationFPS   // 1.0fps → 1초
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
        print("[LiveActivity] Timer started: \(interval)s/frame, frames: \(currentState.animationFrames)")
    }

    private func stopTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Frame advance

    private func tick() {
        guard let activity = currentActivity else { return }

        let count = currentState.animationFrames.count
        guard count > 1 else {
            // 1프레임 상태는 추가 업데이트 불필요
            return
        }

        currentFrame = (currentFrame + 1) % count
        pushUpdate(activity: activity, frame: currentFrame)
    }

    private func pushUpdate(activity: Activity<RichardActivityAttributes>, frame: Int) {
        // 이전 update 요청이 아직 처리 중이면 건너뜀
        guard !isUpdating else {
            print("[LiveActivity] Skipping frame \(frame) — still updating")
            return
        }
        isUpdating = true

        let content = makeContentState(for: currentState, frame: frame)
        let imageName = currentState.animationFrames[safe: frame] ?? "normal_default"
        print("[LiveActivity] → frame:\(frame) img:\(imageName)")

        Task {
            defer {
                // 비동기 작업이 취소되거나 suspended, 에러 혹은 완수가 되더라도 무조건 락을 해제하도록 보장
                Task { @MainActor in
                    self.isUpdating = false
                }
            }
            await activity.update(.init(state: content, staleDate: nil))
        }
    }

    // MARK: - Helpers

    private func makeContentState(
        for state: RichardState,
        frame: Int
    ) -> RichardActivityAttributes.ContentState {
        RichardActivityAttributes.ContentState(
            state:      state,
            stateLabel: state.displayName,
            frameIndex: frame
        )
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
