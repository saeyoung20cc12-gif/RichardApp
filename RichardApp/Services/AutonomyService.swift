import Foundation
import Combine

// MARK: - AutonomyService
/// Tracks real-world time and automatically transitions Richard's state.
/// Publishes `currentState` every minute so the rest of the app can react.
final class AutonomyService: ObservableObject {

    // MARK: - Published
    @Published private(set) var currentState: RichardState

    // MARK: - Schedule constants (Animal Crossing canon)
    private static let wakeHour: Int  = 8   // 08:00
    private static let sleepHour: Int = 23  // 23:00

    /// Hours when Richard eats (breakfast, lunch, snack, dinner)
    private static let mealHours: Set<Int> = [8, 12, 15, 18]

    /// Hours when Richard plays (running outside, reading comics)
    private static let playHours: Set<Int> = [9, 10, 13, 16, 19, 20]

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
        let cal    = Calendar.current
        let hour   = cal.component(.hour,   from: date)
        let minute = cal.component(.minute, from: date)

        // Night: 23:00 → 07:59
        guard hour >= wakeHour && hour < sleepHour else { return .sleeping }

        // Wake-up transition: 08:00 ~ 08:29
        if hour == wakeHour && minute < 30 { return .waking }

        // Meal window
        if mealHours.contains(hour) { return .eating }

        // Play window
        if playHours.contains(hour) { return .playing }

        return .idle
    }

    // MARK: - Private helpers

    private func startTimer() {
        // Fire every 60 seconds on the main run loop so UI can react.
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
