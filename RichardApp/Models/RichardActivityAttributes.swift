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
        var faceImageName: String // e.g. "normal" → 위젯에서 "\(faceImageName)\(frameIndex+1)" 로 사용
        var shortText: String     // e.g. "Zzz..."
        var frameIndex: Int       // 0 or 1 — 타이머가 토글해서 애니메이션 구현

        /// 현재 프레임에 맞는 이미지 asset 이름 반환
        /// e.g. faceImageName="normal", frameIndex=0 → "normal1"
        var currentFrameImageName: String {
            if faceImageName == "test" {
                return "test"
            }
            return "\(faceImageName)\(frameIndex + 1)"
        }
    }

    var appName: String = "리처드"
}
