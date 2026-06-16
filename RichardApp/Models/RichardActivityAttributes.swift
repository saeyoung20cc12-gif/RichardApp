import ActivityKit
import SwiftUI

// MARK: - RichardActivityAttributes
/// Defines the data model for Richard's Live Activity & Dynamic Island.
/// `ContentState` holds state that changes over time (Richard's current action).
struct RichardActivityAttributes: ActivityAttributes {

    // Static info (set once when activity is started)
    public struct ContentState: Codable, Hashable {
        var state: RichardState
        var stateLabel: String    // e.g. "자는 중"
        var frameIndex: Int       // 순환 프레임 인덱스 — 타이머가 증가시켜 애니메이션 구현

        var currentFrameImageName: String {
            let frames = state.animationFrames
            guard !frames.isEmpty else { return "normal_default" }
            return frames[frameIndex % frames.count]
        }
    }

    var appName: String = "리처드"
}
