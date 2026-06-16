import Foundation

// MARK: - Richard's 9 emotional/behavioral states
enum RichardState: String, Codable, CaseIterable {
    case idle       // 기본: 평온한 대기 상태
    case happy      // 행복함: 미소 짓는 상태
    case playing    // 노는중: 신나게 뛰노는 내장 상태 (Dynamic Island에는 happy와 동일하게 표시)
    case eating     // 간식먹는중: 냠냠 먹는 상태
    case crying     // 눈물: 훌쩍훌쩍 우는 상태
    case surprised  // 놀람: 깜짝 놀란 상태
    case missing    // 보고싶어함: 그리워하는 상태
    case annoyed    // 심기불편: 토라진 상태
    case sleeping   // 자는중: 눈을 감고 자는 상태

    var displayName: String {
        switch self {
        case .idle:       return "쉬는 중"
        case .happy:      return "행복함"
        case .playing:    return "노는 중"
        case .eating:     return "먹는 중"
        case .crying:     return "우는 중"
        case .surprised:  return "놀람"
        case .missing:    return "그리워하는 중"
        case .annoyed:    return "토라짐"
        case .sleeping:   return "자는 중"
        }
    }


    /// 상태별 픽셀 아트 프레임 시퀀스 (1fps로 순환 반복)
    /// - playing은 Dynamic Island에 happy와 동일하게 표시 (내장 상태 비노출)
    /// - sleeping은 기본 눈감음 단독 고정 프레임
    /// - eating은 1→2 왕복 후 마지막에 snack3 등장하는 7프레임 루프
    var animationFrames: [String] {
        switch self {
        case .idle:
            return ["normal_default", "normal_blink"]
        case .happy, .playing:
            return ["normal_default", "happy_laugh"]
        case .eating:
            // ActivityKit throttle 방지: 2프레임만 유지
            return ["snack1", "snack2"]
        case .crying:
            return ["cry1", "cry2"]
        case .surprised:
            return ["surprised"]
        case .missing:
            return ["missu"]
        case .annoyed:
            return ["annoyed"]
        case .sleeping:
            return ["normal_blink"]
        }
    }

    /// ActivityKit 안전 갱신 주기: 1.0fps (1초 간격)
    /// — 너무 빠른 업데이트는 ActivityKit이 throttle하여 애니메이션이 멈추는 원인이 됨
    var animationFPS: Double { return 1.0 }
}

// MARK: - Chat Message model
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case richard  // assistant
}

// MARK: - App-wide settings stored in UserDefaults
struct AppSettings {
    static let userNameKey = "userName"

    static var userName: String {
        get { UserDefaults.standard.string(forKey: userNameKey) ?? "보라" }
        set { UserDefaults.standard.set(newValue, forKey: userNameKey) }
    }
}

// MARK: - DailyMission Model
struct DailyMission: Identifiable, Codable, Hashable {
    var id: String { missionId }
    let missionId: String
    let title: String
    let reward: Int
    var isCompleted: Bool
    var isClaimed: Bool
    var progress: Int
    let target: Int
}

// MARK: - SnackItem Model
struct SnackItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let icon: String
    let coinCost: Int
    let hungerFill: Int
    let happinessBonus: Int
    let funBonus: Int
}
