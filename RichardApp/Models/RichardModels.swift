import Foundation

// MARK: - Richard's possible states throughout the day
enum RichardState: String, Codable, CaseIterable {
    case sleeping   // 23:00 ~ 07:59
    case waking     // 08:00 ~ 08:30 (transition)
    case eating     // 밥/간식 먹는 중 (snack 애니메이션)
    case playing    // Running outside / reading comics
    case idle       // Default daytime state (normal 애니메이션)
    case chatting   // When user is talking to Richard (normal 애니메이션)
    case test       // Dynamic Island 확인용 고정 테스트 상태

    var displayName: String {
        switch self {
        case .sleeping: return "자는 중"
        case .waking:   return "일어나는 중"
        case .eating:   return "먹는 중"
        case .playing:  return "노는 중"
        case .idle:     return "쉬는 중"
        case .chatting: return "대화 중"
        case .test:     return "테스트 중"
        }
    }

    /// 애니메이션 베이스 이름 — 위젯에서 "\(faceImageName)\(frameIndex+1)" 형태로 asset 참조
    /// normal → normal1.png / normal2.png (4fps)
    /// snack  → snack1.png  / snack2.png  (1fps)
    var faceImageName: String {
        switch self {
        case .eating:           return "snack"
        case .sleeping,
             .waking,
             .playing,
             .idle,
             .chatting:         return "normal"
        case .test:             return "test"
        }
    }

    /// 상태별 애니메이션 FPS (타이머 간격 계산에 사용)
    /// ActivityKit throttle 고려해 normal은 2fps로 제한
    var animationFPS: Double {
        switch self {
        case .eating:   return 1.0  // snack: 1fps — 느긋하게
        case .test:     return 1.0  // test: 고정 이미지 확인용
        default:        return 2.0  // normal: 2fps — ActivityKit 안전 상한
        }
    }

    /// Short cute text for the right side of the Dynamic Island pill
    var shortText: String {
        switch self {
        case .sleeping: return "Zzz..."
        case .waking:   return "주섬주섬.."
        case .eating:   return "냠냠🍰"
        case .playing:  return "우다다다!"
        case .idle:     return "멍..."
        case .chatting: return "히히!"
        case .test:     return "test"
        }
    }
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
