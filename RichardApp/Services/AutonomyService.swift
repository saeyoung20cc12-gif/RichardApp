import Foundation
import Combine

// MARK: - AutonomyService
/// Tracks real-world time and automatically transitions Richard's state.
/// Publishes `currentState` every 60 seconds so the rest of the app can react.
final class AutonomyService: ObservableObject {

    // MARK: - Published
    @Published private(set) var currentState: RichardState

    // MARK: - Schedule constants
    private static let wakeHour: Int  = 8   // 08:00 기상
    private static let sleepHour: Int = 23  // 23:00 취침

    /// 리처드가 간식/밥을 먹는 시간대 (8, 12, 15, 18시)
    private static let mealHours: Set<Int> = [8, 12, 15, 18]

    // MARK: - Private
    private var timer: AnyCancellable?

    // MARK: - Init / Deinit
    init() {
        self.currentState = AutonomyService.stateForTime(Date())
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    // MARK: - Public API

    /// Force a manual state override (e.g., from a button tap in the UI).
    /// The timer will naturally revert to schedule on the next tick.
    func overrideState(_ state: RichardState) {
        currentState = state
    }

    // MARK: - Static helper (reusable without an instance)

    /// Pure function: given any `Date`, return the correct `RichardState`.
    static func stateForTime(_ date: Date) -> RichardState {
        let cal  = Calendar.current
        let hour = cal.component(.hour, from: date)

        // 밤 시간: 23:00 ~ 07:59 → 자는 중
        guard hour >= wakeHour && hour < sleepHour else { return .sleeping }

        // 식사 시간: 8, 12, 15, 18시 → 간식 먹는 중
        if mealHours.contains(hour) { return .eating }

        // 그 외 낮 시간 → 기본 대기 상태
        return .idle
    }

    // MARK: - Private helpers

    private func startTimer() {
        timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                let newState = AutonomyService.stateForTime(date)
                if newState != self.currentState {
                    self.currentState = newState
                }
            }
    }
}
