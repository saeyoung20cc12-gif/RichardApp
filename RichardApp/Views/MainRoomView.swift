import SwiftUI
import SceneKit

// MARK: - 투명 SCNView (흰 배경 버그 수정)
struct TransparentSceneView: UIViewRepresentable {
    let scene: SCNScene
    let pointOfView: SCNNode
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = scene
        v.pointOfView = pointOfView
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .clear
        v.isOpaque = false
        v.isPlaying = true            // 렌더 루프 항상 실행
        v.rendersContinuously = true  // 매 프레임 렌더링 (CADisplayLink 이동이 반드시 반영됨)
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.backgroundColor = .clear
    }
}

// MARK: - POI
private struct POI { let position: SCNVector3; let weight: Float }

// MARK: - RichardSceneManager
// ✅ April 29 잘 됐던 구조 그대로 복원:
//   characterNode 하나로 위치 + Y회전 모두 관리 (yawNode 없음)
//   container는 X축 보정(-π/2)만 담당
final class RichardSceneManager: NSObject, ObservableObject {

    let scene         = SCNScene()
    let cameraNode    : SCNNode
    private let characterNode : SCNNode
    private let animNode      : SCNNode
    private var activeState: RichardState?
    private var isMoving = false



    private let pois: [POI] = [
        POI(position: SCNVector3( 0.0, -3.8,  1.0), weight: 1.5),
        POI(position: SCNVector3(-2.0, -3.8,  2.0), weight: 1.2),
        POI(position: SCNVector3( 2.0, -3.8,  2.0), weight: 1.2),
        POI(position: SCNVector3(-2.0, -3.8, -0.8), weight: 1.0),
        POI(position: SCNVector3( 2.0, -3.8, -0.8), weight: 1.0),
        POI(position: SCNVector3(-1.0, -3.8, -2.0), weight: 0.8),
        POI(position: SCNVector3( 1.0, -3.8, -2.0), weight: 0.8),
        POI(position: SCNVector3( 0.0, -3.8, -1.5), weight: 0.7),
    ]

    override init() {
        let cam = SCNNode(); cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0, 13)
        cameraNode = cam

        let modelName = "anima_richard"
        let loadedScene: SCNScene?
        if let bundleScene = SCNScene(named: "\(modelName).usdz") {
            loadedScene = bundleScene
        } else if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
            loadedScene = try? SCNScene(url: url, options: nil)
        } else {
            let fallbackURL = URL(fileURLWithPath: "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/\(modelName).usdz")
            loadedScene = try? SCNScene(url: fallbackURL, options: nil)
        }
        let original = loadedScene ?? SCNScene()
        scene.background.contents = UIColor.clear

        let container = SCNNode()
        for child in original.rootNode.childNodes {
            guard let name = child.name else { continue }
            let l = name.lowercased()
            guard !l.contains("camera") && !l.contains("light") &&
                  !l.contains("_material") && !l.contains("env") else { continue }
            container.addChildNode(child)
        }
        container.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)

        container.enumerateChildNodes { node, _ in
            for mat in node.geometry?.materials ?? [] {
                mat.lightingModel = .physicallyBased
                mat.metalness.contents = 0.0
                mat.roughness.contents = 0.8
            }
        }

        var foundAnim: SCNNode = container
        container.enumerateChildNodes { node, stop in
            if !node.animationKeys.isEmpty { foundAnim = node; stop.pointee = true }
        }
        animNode = foundAnim
        animNode.isPaused = true

        let charNode = SCNNode()
        charNode.position = SCNVector3(0, -3.8, 0)
        charNode.addChildNode(container)
        characterNode = charNode

        scene.rootNode.addChildNode(charNode)
        scene.rootNode.addChildNode(cam)
        super.init()
        print("[RichardScene] Model loaded: \(loadedScene != nil ? "✅" : "❌ fallback")")
    }

    // MARK: - 이동 루프 (자연스러운 선 회전 -> 후 이동 순차 제어) ────────────────────
    
    private func shortestAngle(from current: Float, to target: Float) -> Float {
        var diff = target - current
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return current + diff
    }

    func startRoaming(richardState: RichardState) {
        // 상태가 바뀌면 현재 이동 즉시 중단
        if activeState != richardState {
            isMoving = false
            characterNode.removeAllActions()
            characterNode.removeAllAnimations() // CAAnimation 포함 전부 제거
        }

        if isMoving && activeState == richardState { return }

        activeState = richardState

        // eating 상태: 완전 정지
        guard richardState != .eating else {
            animNode.isPaused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, self.activeState == richardState else { return }
                self.isMoving = false
                self.startRoaming(richardState: richardState)
            }
            return
        }

        // sleeping: 천천히 이동 (걷기 애니메이션 OFF)
        // idle/happy/crying 등: 보통 속도
        // playing: 빠른 속도
        let speed: Float
        let walkAnim: Bool
        switch richardState {
        case .sleeping:                  speed = 0.3;  walkAnim = false
        case .playing:                   speed = 1.8;  walkAnim = true
        case .idle, .happy, .missing,
             .crying, .surprised, .annoyed: speed = 1.0; walkAnim = true
        default:                         speed = 1.0;  walkAnim = true
        }

        // 실시간 실제 렌더 포지션 획득 (중간 인터럽트 시 튀는 오류 방지)
        let p0   = characterNode.presentation.position
        let dest = weightedPOI()
        let p2   = dest.position

        let d = dist(p0, p2)
        guard d > 0.4 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, self.activeState == richardState else { return }
                self.isMoving = false
                self.startRoaming(richardState: richardState)
            }
            return
        }

        // 이동 방향각 산출
        let heading = atan2(p2.x - p0.x, p2.z - p0.z)
        
        // 360도 역회전(스핀) 버그를 방지하기 위해 최단 각 경로 정규화
        let curYaw = characterNode.eulerAngles.y
        let targetYaw = shortestAngle(from: curYaw, to: heading)

        animNode.isPaused = true // 회전하는 동안에는 제자리 걷기를 하지 않음
        isMoving = true

        // ── Step 1: 회전 트랜잭션 (제자리에서 0.45초간 목적지를 향해 부드럽게 몸 돌림) ──
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.45
        SCNTransaction.completionBlock = { [weak self] in
            guard let self = self, self.activeState == richardState, self.isMoving else { return }

            // ── Step 2: 이동 트랜잭션 (목적지까지 걷기 애니메이션 활성화 상태로 직선 이동) ──
            self.animNode.isPaused = !walkAnim // 걷기 애니메이션 시작

            let moveDur = max(1.0, Double(d / speed)) // 거리와 상태 속도 기준 산출

            SCNTransaction.begin()
            SCNTransaction.animationDuration = moveDur
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .linear)
            SCNTransaction.completionBlock = { [weak self] in
                guard let self = self, self.activeState == richardState else { return }
                self.isMoving = false

                // 도착 완료 - 걷기 정지
                self.animNode.isPaused = true

                // ── Step 3: 도착 후 짧은 대기 및 좌우 둘러보기(Idle Action) ──
                let idleAction = self.randomIdleAction()
                self.characterNode.runAction(idleAction) { [weak self] in
                    guard let self = self, self.activeState == richardState else { return }
                    self.startRoaming(richardState: richardState)
                }
            }
            // 최종 위치 셋팅
            self.characterNode.position = p2
            SCNTransaction.commit()
        }
        // 최종 Yaw 각도 셋팅 (Pitch/Roll은 0 고정하여 수직 축 유지)
        characterNode.eulerAngles = SCNVector3(0, targetYaw, 0)
        SCNTransaction.commit()
    }

    private func dist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        sqrtf(pow(b.x-a.x,2) + pow(b.z-a.z,2))
    }

    private func weightedPOI() -> POI {
        let total = pois.reduce(0) { $0 + $1.weight }
        var r = Float.random(in: 0..<total)
        for p in pois { r -= p.weight; if r <= 0 { return p } }
        return pois.last!
    }

    private func randomIdleAction() -> SCNAction {
        let wait = Double.random(in: 1.5...3.5)
        switch Int.random(in: 0...2) {
        case 0:
            return SCNAction.wait(duration: wait)
        case 1:
            let l = SCNAction.rotateBy(x: 0, y:  0.3, z: 0, duration: 0.5)
            let r = SCNAction.rotateBy(x: 0, y: -0.6, z: 0, duration: 0.7)
            let b = SCNAction.rotateBy(x: 0, y:  0.3, z: 0, duration: 0.5)
            return SCNAction.sequence([l, r, b, .wait(duration: wait * 0.5)])
        default:
            let peek = SCNAction.rotateBy(x: 0, y:  .pi * 0.4, z: 0, duration: 0.5)
            let back = SCNAction.rotateBy(x: 0, y: -.pi * 0.4, z: 0, duration: 0.5)
            return SCNAction.sequence([peek, .wait(duration: 0.8), back, .wait(duration: wait * 0.5)])
        }
    }
}






// MARK: - MainRoomView
struct MainRoomView: View {
    @EnvironmentObject var appState: AppStateViewModel
    @StateObject private var sceneManager = RichardSceneManager()
    @State private var showChat = false
    @State private var showShop = false
    @State private var showMissions = false
    @State private var showGame = false
    @State private var showNoCoinsAlert = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("room_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    .clipped()
            }
            .ignoresSafeArea()

            TransparentSceneView(scene: sceneManager.scene, pointOfView: sceneManager.cameraNode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header Bar
                HStack(alignment: .center, spacing: 8) {
                    Text("리처드의 방")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "5C4A32"))
                    
                    Button {
                        showMissions = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("📋")
                            Text("미션")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "5C4A32"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "FAF3E8").opacity(0.85)))
                        .overlay(Capsule().stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Text("🪙")
                        Text("\(appState.coins)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "5C4A32"))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "EDD9B8")))
                    .overlay(Capsule().stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                    
                    Text(appState.richardState.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "5C4A32"))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "D4B896")))
                        .overlay(Capsule().stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                .background(Color(hex: "FAF3E8").opacity(0.75).background(.ultraThinMaterial.opacity(0.3)))

                // MARK: Stat Dashboard
                HStack(spacing: 12) {
                    StatBar(icon: "🍗", title: "허기", value: appState.hunger, color: .orange)
                    StatBar(icon: "❤️", title: "행복", value: appState.happiness, color: .red)
                    StatBar(icon: "⭐️", title: "재미", value: appState.fun, color: .blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "FAF3E8").opacity(0.8).background(.ultraThinMaterial.opacity(0.25)))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                HStack(spacing: 14) {
                    TamaButton(title: "밥주기",   icon: .food,
                               color: Color(hex: "F5E6C8"), shadow: Color(hex: "7A4F2D")) {
                        showShop = true
                    }
                    TamaButton(title: "대화하기", icon: .chat,
                               color: Color(hex: "F9D5D3"), shadow: Color(hex: "B03060")) {
                        showChat = true
                    }
                    TamaButton(title: "같이놀기", icon: .play,
                               color: Color(hex: "C8E8F5"), shadow: Color(hex: "1A3A6B")) {
                        if appState.coins > 0 {
                            showGame = true
                        } else {
                            showNoCoinsAlert = true
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
        .onAppear { sceneManager.startRoaming(richardState: appState.richardState) }
        .onChange(of: appState.richardState) { newState in
            sceneManager.startRoaming(richardState: newState)
        }
        .sheet(isPresented: $showChat) { ChatView().environmentObject(appState) }
        .sheet(isPresented: $showShop) { ShopSheet().environmentObject(appState) }
        .sheet(isPresented: $showMissions) { MissionsSheet().environmentObject(appState) }
        .sheet(isPresented: $showGame) { GameSheet().environmentObject(appState) }
        .alert("코인 부족", isPresented: $showNoCoinsAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("코인이 부족합니다. 게임을 하려면 최소 1코인이 필요합니다!")
        }
    }
}

// MARK: - 다마고치 커스텀 게이지 바 UI
struct StatBar: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "5C4A32"))
                Spacer()
                Text("\(value)/100")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "5C4A32"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: "FAF3E8").opacity(0.8))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(hex: "5C4A32"), lineWidth: 1.5)
                        )
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 일일 미션 관리 시트
struct MissionsSheet: View {
    @EnvironmentObject var appState: AppStateViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FAF3E8").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(appState.missions) { mission in
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(mission.title)
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "5C4A32"))
                                    
                                    if mission.missionId.hasPrefix("steps_") {
                                        HStack(spacing: 6) {
                                            ProgressView(value: Double(min(appState.steps, mission.target)), total: Double(mission.target))
                                                .progressViewStyle(.linear)
                                                .tint(.orange)
                                                .frame(width: 80)
                                            Text("\(appState.steps) / \(mission.target) 걸음")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(.gray)
                                        }
                                    } else {
                                        Text(mission.isCompleted ? "미션 달성 완료! 🎉" : "미션 진행 중 🏃")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(mission.isCompleted ? .green : .gray)
                                    }
                                }
                                Spacer()
                                
                                if mission.isClaimed {
                                    Text("수령 완료")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.5)))
                                } else if mission.isCompleted {
                                    Button {
                                        appState.claimMissionReward(missionId: mission.missionId)
                                    } label: {
                                        Text("보상 수령 (\(mission.reward)🪙)")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.orange)
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "7A4F2D"), lineWidth: 1.5))
                                            )
                                    }
                                } else {
                                    if mission.missionId == "attendance" {
                                        Button {
                                            appState.completeAttendanceMission()
                                        } label: {
                                            Text("출석하기")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(hex: "C8E8F5"))
                                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "1A3A6B"), lineWidth: 1.5))
                                                )
                                                .foregroundColor(Color(hex: "1A3A6B"))
                                        }
                                    } else if mission.missionId == "outing" {
                                        Button {
                                            appState.completeOutingMission()
                                        } label: {
                                            Text("외출 완료")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(hex: "F9D5D3"))
                                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "B03060"), lineWidth: 1.5))
                                                )
                                                .foregroundColor(Color(hex: "B03060"))
                                        }
                                    } else {
                                        Text("진행 중")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                        }
                        
                        // 디버그 가상 스텝 증가 기능 추가
                        VStack(spacing: 8) {
                            Text("⚙️ 가상 스피커/시뮬레이터 테스트")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            
                            Button {
                                appState.addMockSteps(500)
                            } label: {
                                Text("가상 500보 걷기 (시뮬레이터용)")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.5))
                                    )
                            }
                        }
                        .padding(.top, 14)
                    }
                    .padding()
                }
            }
            .navigationTitle("📋 일일 미션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(Color(hex: "5C4A32"))
                }
            }
        }
    }
}

// MARK: - 간식 상점 시트
struct ShopSheet: View {
    @EnvironmentObject var appState: AppStateViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FAF3E8").ignoresSafeArea()
                
                VStack(spacing: 16) {
                    HStack {
                        Text("🪙 내 잔여 코인: \(appState.coins) Coins")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "5C4A32"))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(appState.snacksList) { snack in
                                HStack(spacing: 16) {
                                    Text(snack.icon)
                                        .font(.system(size: 36))
                                        .padding(10)
                                        .background(Circle().fill(Color(hex: "FAF3E8")))
                                        .overlay(Circle().stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(snack.name)
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                            .foregroundColor(Color(hex: "5C4A32"))
                                        
                                        Text("허기 +\(snack.hungerFill) \(snack.happinessBonus > 0 ? " 행복도 +\(snack.happinessBonus)" : "") \(snack.funBonus > 0 ? " 재미 +\(snack.funBonus)" : "")")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        if appState.buyAndFeedSnack(snack: snack) {
                                            dismiss()
                                        }
                                    } label: {
                                        HStack(spacing: 3) {
                                            Text("\(snack.coinCost)")
                                                .font(.system(size: 12, weight: .bold))
                                            Text("🪙")
                                        }
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(appState.coins >= snack.coinCost ? Color(hex: "7A4F2D") : Color.gray)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(appState.coins >= snack.coinCost ? Color(hex: "F5E6C8") : Color.gray.opacity(0.2))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(appState.coins >= snack.coinCost ? Color(hex: "7A4F2D") : Color.gray, lineWidth: 1.5)
                                                )
                                        )
                                    }
                                    .disabled(appState.coins < snack.coinCost)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "5C4A32"), lineWidth: 1.5))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("🧁 리처드의 간식 상점")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(Color(hex: "5C4A32"))
                }
            }
        }
    }
}

// MARK: - 👾 하이로우 미니게임 시트
struct GameSheet: View {
    @EnvironmentObject var appState: AppStateViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FAF3E8").ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("👾 하이로우 카드 게임")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "5C4A32"))
                    
                    Text("🪙 보유 자산: \(appState.coins) Coins (참가비 5🪙)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "5C4A32"))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "EDD9B8")))
                        .overlay(Capsule().stroke(Color(hex: "5C4A32"), lineWidth: 1))
                    
                    if !appState.isGameActive {
                        VStack(spacing: 16) {
                            Text("첫 번째 카드를 뽑은 후,\n다음에 공개될 카드가 이 카드보다\n높을지(High) 낮을지(Low) 예측해보세요!")
                                .multilineTextAlignment(.center)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "5C4A32"))
                                .lineSpacing(6)
                            
                            Button {
                                _ = appState.startNewGame()
                            } label: {
                                Text("🎮 첫 장 뽑기")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: "C8E8F5"))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "1A3A6B"), lineWidth: 2))
                                    )
                                    .foregroundColor(Color(hex: "1A3A6B"))
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "5C4A32"), lineWidth: 2))
                        .padding()
                    } else {
                        VStack(spacing: 20) {
                            Text(appState.gameStatusMessage)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "5C4A32"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            HStack(spacing: 24) {
                                VStack(spacing: 6) {
                                    Text("현재 카드")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(.gray)
                                    PixelCardView(value: appState.gameCurrentCardValue, isFaceUp: true)
                                }
                                
                                VStack(spacing: 6) {
                                    Text("다음 카드")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(.gray)
                                    
                                    if let _ = appState.gameResult {
                                        PixelCardView(value: appState.gameNextCardValue, isFaceUp: true)
                                    } else {
                                        PixelCardView(value: 0, isFaceUp: false)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            
                            if appState.gameResult == nil {
                                HStack(spacing: 16) {
                                    Button {
                                        appState.playHiLow(guessHigh: true)
                                    } label: {
                                        Text("🔺 하이 (High)")
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20).padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(hex: "F9D5D3"))
                                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "B03060"), lineWidth: 2))
                                            )
                                            .foregroundColor(Color(hex: "B03060"))
                                    }
                                    
                                    Button {
                                        appState.playHiLow(guessHigh: false)
                                    } label: {
                                        Text("🔻 로우 (Low)")
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20).padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(hex: "C8E8F5"))
                                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "1A3A6B"), lineWidth: 2))
                                            )
                                            .foregroundColor(Color(hex: "1A3A6B"))
                                    }
                                }
                            } else {
                                Button {
                                    if appState.coins > 0 {
                                        _ = appState.startNewGame()
                                    } else {
                                        dismiss()
                                    }
                                } label: {
                                    Text(appState.coins > 0 ? "한 판 더 하기 🎮" : "돌아가기")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24).padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(hex: "F5E6C8"))
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "7A4F2D"), lineWidth: 2))
                                        )
                                        .foregroundColor(Color(hex: "7A4F2D"))
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "5C4A32"), lineWidth: 2))
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(Color(hex: "5C4A32"))
                }
            }
        }
    }
}

// MARK: - 👾 Pinterest 하트 A 감성을 적용한 동적 도트 카드 컴포넌트
struct PixelCardView: View {
    let value: Int
    let isFaceUp: Bool
    
    var body: some View {
        ZStack {
            if isFaceUp {
                ZStack {
                    // A하트 카드는 다운로드된 Pinterest 이미지를 100% 그대로 픽셀 렌더링
                    if value == 1 {
                        Image("pixel_card_front")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        // 다른 카드들은 A하트 디자인 템플릿의 색상, 비율, 도트 감성을 완벽히 조화하여 동적 렌더링
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "FAF3E8")) // 오프화이트 도트 컬러
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black, lineWidth: 3.5) // 두꺼운 검정 도트 테두리
                            )
                            .overlay(
                                // Pinterest 카드 고유의 좌상->우하 대각선 하이라이트 픽셀 감성 구현
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 150))
                                    path.addLine(to: CGPoint(x: 100, y: 0))
                                    path.addLine(to: CGPoint(x: 100, y: 150))
                                    path.closeSubpath()
                                }
                                .fill(Color.white.opacity(0.45))
                            )
                        
                        // 카드 내부 텍스트 및 픽셀 문양 오버레이
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cardName)
                                        .font(.system(size: 20, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                    Text(suitIcon)
                                        .font(.system(size: 14))
                                }
                                Spacer()
                            }
                            .padding(.top, 10)
                            .padding(.horizontal, 10)
                            
                            Spacer()
                            
                            Text(suitIcon)
                                .font(.system(size: 40))
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                            
                            Spacer()
                            
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(suitIcon)
                                        .font(.system(size: 14))
                                    Text(cardName)
                                        .font(.system(size: 20, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.bottom, 10)
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // 카드 뒷면: 8-bit Duck 옐로우 도트 카드 뒷면 적용!
                Image("pixel_card_back")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
    }
    
    private var cardName: String {
        switch value {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(value)"
        }
    }
    
    private var suitIcon: String {
        switch value % 4 {
        case 0: return "♠️"
        case 1: return "♥️"
        case 2: return "♦️"
        default: return "♣️"
        }
    }
}

// MARK: - 다마고치 스타일 버튼
struct TamaButton: View {
    let title: String
    let icon: TamaIcon
    let color: Color
    let shadow: Color
    let action: () -> Void

    @State private var isPressed = false
    private let depth: CGFloat = 5

    var body: some View {
        Button(action: { action() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(shadow)
                    .offset(x: isPressed ? 0 : depth, y: isPressed ? 0 : depth)

                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(shadow, lineWidth: 2.5))
                    .offset(x: isPressed ? depth : 0, y: isPressed ? depth : 0)

                VStack(spacing: 6) {
                    PixelIcon(icon: icon, tint: shadow)
                        .frame(width: 36, height: 36)
                    Text(title)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(shadow)
                        .tracking(0.5)
                }
                .offset(x: isPressed ? depth : 0, y: isPressed ? depth : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { isPressed = false } }
        )
    }
}

// MARK: - 픽셀아트 아이콘 타입
enum TamaIcon {
    case food, chat, play

    // 0 = 빈칸, 1 = 채움, 2 = 연한 색
    var grid: [[Int]] {
        switch self {
        case .food:   return TamaIcon.foodGrid
        case .chat:   return TamaIcon.chatGrid
        case .play:   return TamaIcon.playGrid
        }
    }

    // 🍙 첥밥주기: 스팀 오르는 귀여운 밥그룷
    private static let foodGrid: [[Int]] = [
        [0,0,1,0,1,0,0,0],
        [0,0,1,0,1,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,1,1,1,1,1,1,0],
        [1,2,1,2,1,2,1,1],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,0,0],
    ]

    // 💭 말풍선: 둥근 버블 + 점 세 개
    private static let chatGrid: [[Int]] = [
        [0,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1],
        [1,0,1,0,1,0,0,1],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,0,0,0,0],
        [0,0,0,1,0,0,0,0],
        [0,0,0,0,0,0,0,0],
    ]

    // ⭐️ 별: 다섹형 + 말초
    private static let playGrid: [[Int]] = [
        [0,0,0,1,1,0,0,0],
        [0,0,1,1,1,1,0,0],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,0,0],
        [0,1,1,0,0,1,1,0],
        [1,1,0,0,0,0,1,1],
        [0,0,0,0,0,0,0,0],
    ]
}

// MARK: - 픽셀 렌더러
struct PixelIcon: View {
    let icon: TamaIcon
    let tint: Color
    private let ps: CGFloat = 3.5   // pixel size
    private let gap: CGFloat = 0.8  // pixel gap

    var body: some View {
        Canvas { ctx, _ in
            let grid = icon.grid
            for (r, row) in grid.enumerated() {
                for (c, val) in row.enumerated() {
                    guard val > 0 else { continue }
                    let x = CGFloat(c) * (ps + gap)
                    let y = CGFloat(r) * (ps + gap)
                    let rect = CGRect(x: x, y: y, width: ps, height: ps)
                    ctx.fill(
                        Path(rect),
                        with: .color(val == 2 ? tint.opacity(0.35) : tint)
                    )
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex); var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
    }
}

#Preview { MainRoomView().environmentObject(AppStateViewModel()) }
