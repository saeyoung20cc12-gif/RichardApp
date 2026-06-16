import Foundation
import Combine
import CoreMotion

// MARK: - AppStateViewModel
/// The single source of truth for the entire app's state.
/// Injected as @EnvironmentObject into all views.
@MainActor
final class AppStateViewModel: ObservableObject {

    // MARK: Published State
    @Published var richardState: RichardState = .idle
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var userName: String = AppSettings.userName {
        didSet { AppSettings.userName = userName }
    }

    // 다마고치 핵심 수치
    @Published var hunger: Int = 50 {
        didSet {
            let clamped = max(0, min(100, hunger))
            if clamped != hunger {
                hunger = clamped
            } else {
                UserDefaults.standard.set(hunger, forKey: "richard_hunger")
            }
        }
    }
    @Published var happiness: Int = 50 {
        didSet {
            let clamped = max(0, min(100, happiness))
            if clamped != happiness {
                happiness = clamped
            } else {
                UserDefaults.standard.set(happiness, forKey: "richard_happiness")
                checkHappinessTriggers()
            }
        }
    }
    @Published var fun: Int = 50 {
        didSet {
            let clamped = max(0, min(100, fun))
            if clamped != fun {
                fun = clamped
            } else {
                UserDefaults.standard.set(fun, forKey: "richard_fun")
            }
        }
    }
    @Published var coins: Int = 30 {
        didSet {
            let clamped = max(0, coins)
            if clamped != coins {
                coins = clamped
            } else {
                UserDefaults.standard.set(coins, forKey: "richard_coins")
            }
        }
    }
    @Published var missions: [DailyMission] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(missions) {
                UserDefaults.standard.set(data, forKey: "richard_missions")
            }
        }
    }
    @Published var steps: Int = 0 {
        didSet {
            UserDefaults.standard.set(steps, forKey: "richard_steps")
            updateStepMissions()
        }
    }

    // 하이로우 게임 상태
    @Published var gameCurrentCardValue: Int = Int.random(in: 1...13)
    @Published var gameNextCardValue: Int = 0
    @Published var gameStatusMessage: String = "하이(High) 혹은 로우(Low)를 골라주세요!"
    @Published var isGameActive: Bool = false
    @Published var gameResult: String? = nil // "win", "lose"

    // MARK: Services
    private let llmService      = LLMService()
    private let autonomyService = AutonomyService()
    private let liveActivity    = LiveActivityService.shared
    private let pedometer       = CMPedometer()

    private var cancellables = Set<AnyCancellable>()
    private var eatingExpirationDate: Date?
    private var eatingTimer: Timer?

    // MARK: - Init
    init() {
        // UserDefaults 로드
        let savedHunger = UserDefaults.standard.object(forKey: "richard_hunger") as? Int ?? 50
        let savedHappiness = UserDefaults.standard.object(forKey: "richard_happiness") as? Int ?? 50
        let savedFun = UserDefaults.standard.object(forKey: "richard_fun") as? Int ?? 50
        let savedCoins = UserDefaults.standard.object(forKey: "richard_coins") as? Int ?? 30
        let savedSteps = UserDefaults.standard.object(forKey: "richard_steps") as? Int ?? 0

        self.hunger = savedHunger
        self.happiness = savedHappiness
        self.fun = savedFun
        self.coins = savedCoins
        self.steps = savedSteps

        if let data = UserDefaults.standard.data(forKey: "richard_missions"),
           let loadedMissions = try? JSONDecoder().decode([DailyMission].self, from: data) {
            self.missions = loadedMissions
        } else {
            self.missions = AppStateViewModel.createDefaultMissions(currentSteps: savedSteps)
        }

        let initialState = autonomyService.currentState
        self.richardState = initialState

        // AutonomyService의 시간 기반 자동 상태 전환만 구독
        autonomyService.$currentState
            .dropFirst()              // 초기값 중복 발행 제거
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // 일일 미션 자정 리셋 및 자연 행복도 감쇄 체크 (60초마다 수행)
                    self.checkDailyReset()
                    self.applyHappinessDecay()

                    // 간식 상태 락 시간 동안은 외부의 상태 전환(AutonomyService 등)을 무시합니다.
                    if let exp = self.eatingExpirationDate, Date() < exp {
                        print("[State] Ignoring Autonomy update to \(newState.displayName) because eating state is locked.")
                        return
                    }
                    // 시간 스케줄러에 의한 자동 전환: happy 60% 확률 적용
                    let resolved = self.resolveState(newState)
                    self.richardState = resolved
                    self.liveActivity.update(to: resolved)
                }
            }
            .store(in: &cancellables)

        // Live Activity 시작
        Task { @MainActor in
            liveActivity.start(with: initialState)
        }
        
        // 걸음수 연동 시작 및 초기값 보정
        self.checkDailyReset()
        self.applyHappinessDecay()
        self.startPedometerUpdates()
    }

    // MARK: - Public Intents

    /// UI 버튼 탭 등 수동 상태 변경
    /// AutonomyService를 우회해 직접 상태를 적용 (Combine 루프 없음)
    func updateState(_ newState: RichardState) {
        let resolved = resolveState(newState)
        
        if resolved == .eating {
            // 5분(300초) 동안 간식 상태를 락하고, 5분 뒤에 자동 복원하기 위한 타이머를 설정합니다.
            self.eatingExpirationDate = Date().addingTimeInterval(300)
            
            // 기존 타이머가 있다면 무효화
            self.eatingTimer?.invalidate()
            self.eatingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.eatingExpirationDate = nil
                    // 5분이 지났으므로 현재 시간대에 맞는 상태로 복원
                    let scheduleState = AutonomyService.stateForTime(Date())
                    let resolvedRestore = self.resolveState(scheduleState)
                    print("[State] Eating state duration completed. Restoring to \(resolvedRestore.displayName)")
                    self.richardState = resolvedRestore
                    self.liveActivity.update(to: resolvedRestore)
                    self.autonomyService.overrideState(resolvedRestore)
                }
            }
        } else {
            // 다른 상태로 강제 전환되면 간식 락을 해제합니다.
            self.eatingExpirationDate = nil
            self.eatingTimer?.invalidate()
            self.eatingTimer = nil
        }
        
        richardState = resolved
        liveActivity.update(to: resolved)
        // AutonomyService에 override 등록
        autonomyService.overrideState(resolved)
        print("[State] Manual override → \(resolved.displayName)")
    }

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
                        self.isLoading = (index < lines.count - 1)
                    }

                    if index < lines.count - 1 {
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

    // MARK: - Private

    /// happy 상태 진입 시 60% 확률로 playing으로 전환하는 내부 결정 함수
    private func resolveState(_ state: RichardState) -> RichardState {
        guard state == .happy else { return state }
        if Double.random(in: 0...1) <= 0.6 {
            print("[State] happy → playing (60% 확률 발동!)")
            return .playing
        }
        return .happy
    }

    // MARK: - 다마고치 로직 추가 구현

    private func checkHappinessTriggers() {
        if happiness == 0 {
            if richardState != .crying {
                updateState(.crying)
            }
        } else if happiness <= 10 {
            if richardState != .annoyed {
                updateState(.annoyed)
            }
        } else if happiness <= 20 {
            if richardState != .missing {
                updateState(.missing)
            }
        } else {
            // 행복도가 20을 넘어서 회복되면 정상 대기 상태로 복구
            if richardState == .crying || richardState == .annoyed || richardState == .missing {
                updateState(.idle)
            }
        }
    }

    static func createDefaultMissions(currentSteps: Int) -> [DailyMission] {
        var list: [DailyMission] = [
            DailyMission(missionId: "attendance", title: "일일 출석체크 하기", reward: 10, isCompleted: false, isClaimed: false, progress: 0, target: 1),
            DailyMission(missionId: "outing", title: "리처드와 외출 다녀오기", reward: 20, isCompleted: false, isClaimed: false, progress: 0, target: 1)
        ]
        // 500보 단위로 5000보까지 10단계 생성
        for i in 1...10 {
            let target = i * 500
            list.append(DailyMission(
                missionId: "steps_\(target)",
                title: "오늘 \(target)걸음 걷기",
                reward: 10,
                isCompleted: currentSteps >= target,
                isClaimed: false,
                progress: currentSteps,
                target: target
            ))
        }
        return list
    }

    func applyHappinessDecay() {
        let now = Date()
        if let lastDate = UserDefaults.standard.object(forKey: "richard_last_active_date") as? Date {
            let elapsed = now.timeIntervalSince(lastDate)
            let hours = Int(elapsed / 3600)
            if hours > 0 {
                let decay = hours * 5
                self.happiness = max(0, self.happiness - decay)
                print("[Decay] \(hours) hours elapsed. Happiness decayed by \(decay). Current: \(self.happiness)")
                
                let newLastDate = lastDate.addingTimeInterval(Double(hours) * 3600)
                UserDefaults.standard.set(newLastDate, forKey: "richard_last_active_date")
            }
        } else {
            UserDefaults.standard.set(now, forKey: "richard_last_active_date")
        }
    }

    func checkDailyReset() {
        let now = Date()
        let cal = Calendar.current
        let lastReset = UserDefaults.standard.object(forKey: "richard_last_reset_date") as? Date ?? Date.distantPast
        
        if !cal.isDate(now, inSameDayAs: lastReset) {
            print("[Reset] New day detected! Resetting daily missions and steps.")
            self.steps = 0
            self.missions = AppStateViewModel.createDefaultMissions(currentSteps: 0)
            UserDefaults.standard.set(now, forKey: "richard_last_reset_date")
        }
    }

    func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("[Pedometer] Step counting not available on this device.")
            return
        }
        
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        
        pedometer.startUpdates(from: todayStart) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            let stepCount = data.numberOfSteps.intValue
            
            Task { @MainActor in
                self.steps = max(self.steps, stepCount)
            }
        }
    }

    func addMockSteps(_ count: Int) {
        self.steps += count
        print("[Pedometer] Manually added \(count) mock steps. Current total: \(self.steps)")
    }

    private func updateStepMissions() {
        for index in 0..<missions.count {
            if missions[index].missionId.hasPrefix("steps_") {
                missions[index].progress = steps
                if steps >= missions[index].target {
                    missions[index].isCompleted = true
                }
            }
        }
    }

    func claimMissionReward(missionId: String) {
        guard let index = missions.firstIndex(where: { $0.missionId == missionId }) else { return }
        guard missions[index].isCompleted && !missions[index].isClaimed else { return }
        
        missions[index].isClaimed = true
        self.coins += missions[index].reward
    }
    
    func completeOutingMission() {
        guard let index = missions.firstIndex(where: { $0.missionId == "outing" }) else { return }
        missions[index].progress = 1
        missions[index].isCompleted = true
    }
    
    func completeAttendanceMission() {
        guard let index = missions.firstIndex(where: { $0.missionId == "attendance" }) else { return }
        missions[index].progress = 1
        missions[index].isCompleted = true
    }

    // 하이로우 미니게임 로직

    func startNewGame() -> Bool {
        guard coins > 0 else {
            print("[Game] Cannot start game: 0 coins.")
            return false
        }
        
        gameCurrentCardValue = Int.random(in: 1...13)
        gameNextCardValue = 0
        gameStatusMessage = "과연 다음 카드는 현재 카드보다 높을까요(High), 낮을까요(Low)?"
        gameResult = nil
        isGameActive = true
        return true
    }
    
    func playHiLow(guessHigh: Bool) {
        guard coins > 0 else { return }
        
        var nextVal = Int.random(in: 1...13)
        while nextVal == gameCurrentCardValue {
            nextVal = Int.random(in: 1...13)
        }
        gameNextCardValue = nextVal
        
        let isHigher = gameNextCardValue > gameCurrentCardValue
        let won = (guessHigh && isHigher) || (!guessHigh && !isHigher)
        
        if won {
            gameResult = "win"
            self.coins += 15
            self.hunger = max(0, self.hunger - 10)
            self.fun = min(100, self.fun + 15)
            gameStatusMessage = "축하합니다! 맞췄습니다! (+15 코인)"
            updateState(.playing)
        } else {
            gameResult = "lose"
            self.coins = max(0, self.coins - 5)
            self.hunger = max(0, self.hunger - 10)
            self.fun = min(100, self.fun + 15)
            gameStatusMessage = "아쉽게도 틀렸습니다... (-5 코인)"
            updateState(.playing)
        }
    }
    
    func cardName(for value: Int) -> String {
        switch value {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(value)"
        }
    }

    // 상점 간식 목록 및 간식 가격 차별화
    
    var snacksList: [SnackItem] {
        return [
            SnackItem(id: "riceball", name: "초록 주먹밥", icon: "🍙", coinCost: 10, hungerFill: 10, happinessBonus: 0, funBonus: 0),
            SnackItem(id: "cupcake", name: "레몬 컵케이크", icon: "🧁", coinCost: 15, hungerFill: 15, happinessBonus: 5, funBonus: 0),
            SnackItem(id: "applepie", name: "애플 파이", icon: "🍎", coinCost: 25, hungerFill: 20, happinessBonus: 10, funBonus: 5)
        ]
    }
    
    func buyAndFeedSnack(snack: SnackItem) -> Bool {
        guard coins >= snack.coinCost else {
            print("[Shop] Not enough coins to buy \(snack.name)")
            return false
        }
        
        self.coins -= snack.coinCost
        self.hunger = min(100, self.hunger + snack.hungerFill)
        self.happiness = min(100, self.happiness + snack.happinessBonus)
        self.fun = min(100, self.fun + snack.funBonus)
        
        // 밥 먹는 애니메이션 트리거
        updateState(.eating)
        print("[Shop] Successfully purchased and fed \(snack.name). Coins left: \(self.coins)")
        return true
    }
}
