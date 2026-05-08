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
    private let characterNode : SCNNode   // 위치 + 회전 모두
    private let animNode      : SCNNode   // isPaused 토글용

    private let pois: [POI] = [
        POI(position: SCNVector3( 0.0, -1.5,  0.0), weight: 2.0),
        POI(position: SCNVector3(-3.5, -1.5,  0.0), weight: 1.0),
        POI(position: SCNVector3( 3.5, -1.5,  0.0), weight: 1.0),
        POI(position: SCNVector3(-2.5, -1.5,  1.5), weight: 0.8),
        POI(position: SCNVector3( 2.5, -1.5,  1.5), weight: 0.8),
        POI(position: SCNVector3(-1.5, -1.5, -1.0), weight: 0.5),
        POI(position: SCNVector3( 1.5, -1.5, -1.0), weight: 0.5),
    ]

    override init() {
        let cam = SCNNode(); cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0, 13)
        cameraNode = cam

        let original = SCNScene(named: "anima_richard.usdz")!
        scene.background.contents = UIColor.clear

        let container = SCNNode()
        for child in original.rootNode.childNodes {
            guard let name = child.name else { continue }
            let l = name.lowercased()
            guard !l.contains("camera") && !l.contains("light") &&
                  !l.contains("_material") && !l.contains("env") else { continue }
            container.addChildNode(child)
        }
        // Blender Z-up → SceneKit Y-up 축 보정
        container.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)

        container.enumerateChildNodes { node, _ in
            for mat in node.geometry?.materials ?? [] {
                mat.lightingModel = .physicallyBased
                mat.metalness.contents = 0.0
                mat.roughness.contents = 0.8
            }
        }

        // 애니메이션 노드 탐색
        var foundAnim: SCNNode = container
        container.enumerateChildNodes { node, stop in
            if !node.animationKeys.isEmpty { foundAnim = node; stop.pointee = true }
        }
        animNode = foundAnim
        animNode.isPaused = true

        // characterNode: 위치 + 회전을 직접 담당 (April 29 원본 구조)
        let charNode = SCNNode()
        charNode.position = SCNVector3(0, -1.5, 0)
        charNode.addChildNode(container)
        characterNode = charNode

        scene.rootNode.addChildNode(charNode)
        scene.rootNode.addChildNode(cam)
        super.init()
    }

    // MARK: - 로밍 루프 (April 29 원본 구조 복원)
    func startRoaming(richardState: RichardState) {
        guard richardState != .sleeping, richardState != .eating else {
            animNode.isPaused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startRoaming(richardState: richardState)
            }
            return
        }

        let speed: Float = richardState == .playing ? 1.8 : (richardState == .waking ? 0.6 : 1.0)
        let dest = weightedPOI()
        let cur  = characterNode.presentation.position
        let dx = dest.position.x - cur.x
        let dz = dest.position.z - cur.z
        let dist = sqrtf(dx*dx + dz*dz)

        guard dist > 0.3 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startRoaming(richardState: richardState)
            }
            return
        }

        let moveDur  = Double(dist / speed)
        let heading  = atan2(dx, dz)

        // ✅ April 29 원본: characterNode에 직접 rotateTo
        let rotateAction = SCNAction.rotateTo(
            x: 0, y: CGFloat(heading), z: 0,
            duration: 0.6,
            usesShortestUnitArc: true
        )

        let anim = animNode
        let startWalk = SCNAction.run { _ in anim.isPaused = false }
        let move      = SCNAction.move(to: dest.position, duration: moveDur)
        move.timingMode = .linear
        let stopWalk  = SCNAction.run { _ in anim.isPaused = true }
        let idle      = randomIdleAction()

        let seq = SCNAction.sequence([rotateAction, startWalk, move, stopWalk, idle])

        characterNode.removeAllActions()
        characterNode.runAction(seq) { [weak self] in
            DispatchQueue.main.async { self?.startRoaming(richardState: richardState) }
        }
    }

    private func weightedPOI() -> POI {
        let total = pois.reduce(0) { $0 + $1.weight }
        var r = Float.random(in: 0..<total)
        for p in pois { r -= p.weight; if r <= 0 { return p } }
        return pois.last!
    }

    // ✅ April 29 원본: characterNode에 rotateBy
    private func randomIdleAction() -> SCNAction {
        let wait = Double.random(in: 1.5...4.0)
        switch Int.random(in: 0...2) {
        case 0:
            return SCNAction.wait(duration: wait)
        case 1:
            let left  = SCNAction.rotateBy(x: 0, y:  0.3, z: 0, duration: 0.5)
            let right = SCNAction.rotateBy(x: 0, y: -0.6, z: 0, duration: 0.7)
            let back  = SCNAction.rotateBy(x: 0, y:  0.3, z: 0, duration: 0.5)
            return SCNAction.sequence([left, right, back, .wait(duration: wait * 0.5)])
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2D6A4F"), Color(hex: "1B4332"), Color(hex: "081C15")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            TransparentSceneView(scene: sceneManager.scene, pointOfView: sceneManager.cameraNode)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("리처드의 방")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(appState.richardState.displayName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(appState.richardState.shortText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "1B4332"))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color(hex: "95D5B2")))
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
                .background(Color.black.opacity(0.25).background(.ultraThinMaterial.opacity(0.4)))

                Spacer()

                HStack(spacing: 14) {
                    TamaButton(title: "밥주기",   icon: .food,
                               color: Color(hex: "F5E6C8"), shadow: Color(hex: "7A4F2D")) {
                        appState.updateState(.eating)
                    }
                    TamaButton(title: "대화하기", icon: .chat,
                               color: Color(hex: "F9D5D3"), shadow: Color(hex: "B03060")) {
                        showChat = true
                    }
                    TamaButton(title: "같이놀기", icon: .play,
                               color: Color(hex: "C8E8F5"), shadow: Color(hex: "1A3A6B")) {
                        appState.updateState(.playing)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
        .onAppear { sceneManager.startRoaming(richardState: appState.richardState) }
        .sheet(isPresented: $showChat) { ChatView().environmentObject(appState) }
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
