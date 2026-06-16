import SwiftUI

// MARK: - ChatView
/// Full-screen chat interface for talking to Richard.
struct ChatView: View {
    @EnvironmentObject var appState: AppStateViewModel
    @Environment(\.dismiss) var dismiss

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    // 리처드의 방과 동일한 따뜻한 베이지 색상 시스템
    private let bgTop    = Color(hex: "FAF3E8")
    private let bgBottom = Color(hex: "EDD9B8")
    private let accent   = Color(hex: "D4B896")
    private let dark     = Color(hex: "5C4A32")
    private let richBubble = Color(hex: "D4B896")
    private let userBubble = Color(hex: "8B6F4E")

    var body: some View {
        NavigationStack {
            ZStack {
                // 리처드의 방과 동일 계열 따뜻한 베이지 그라디언트 배경
                LinearGradient(
                    colors: [bgTop, bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Chat messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                // Greeting message
                                if appState.chatMessages.isEmpty {
                                    GreetingBubble(state: appState.richardState)
                                        .padding(.top, 20)
                                }

                                ForEach(appState.chatMessages) { message in
                                    MessageBubble(message: message,
                                                  richardBubble: richBubble,
                                                  userBubble: userBubble,
                                                  dark: dark,
                                                  state: appState.richardState)
                                        .id(message.id)
                                }

                                if appState.isLoading {
                                    RichardTypingIndicator(state: appState.richardState,
                                                           bubbleColor: richBubble,
                                                           dark: dark)
                                }

                                // 스크롤 앵커용 빈 뷰
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: appState.chatMessages.count) { _, _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: appState.isLoading) { _, loading in
                            if loading {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                    }

                    // MARK: Input bar
                    HStack(spacing: 12) {
                        TextField("리처드에게 말 걸기...", text: $inputText, axis: .vertical)
                            .lineLimit(4)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "FAF3E8").opacity(0.8))
                            )
                            .foregroundColor(dark)
                            .focused($isInputFocused)
                            .tint(dark)

                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color(hex: "8B6F4E").opacity(0.4) : .white)
                                .font(.system(size: 18))
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                              ? accent.opacity(0.3)
                                              : Color(hex: "7A4F2D"))
                                )
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || appState.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        Color(hex: "FAF3E8").opacity(0.85)
                            .background(.ultraThinMaterial.opacity(0.4))
                    )
                }
            }
            .navigationTitle("리처드의 방")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(dark)
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendMessage(text)
        
        // 채팅을 한 번 보내면 랜덤으로 5~10이 증가
        let happinessBonus = Int.random(in: 5...10)
        appState.happiness = min(100, appState.happiness + happinessBonus)
        print("[Chat] Happiness increased by \(happinessBonus). Total: \(appState.happiness)")
    }
}

// MARK: - RichardAvatar (에셋 도트 이미지 뱃지)
/// 에셋에 저장된 실제 픽셀 아트 도트 이미지를 원형 베이지 배경 위에 표시합니다.
/// 검정 배경 픽셀은 런타임에 투명 처리하여 깔끔하게 합성합니다.
struct RichardAvatar: View {
    let state: RichardState
    let size: CGFloat

    private var imageName: String {
        state.animationFrames.first ?? "normal_default"
    }

    /// 검정 배경이 제거된 UIImage (24×24이라 성능 영향 없음)
    private var processedImage: UIImage? {
        UIImage(named: imageName)?.removingDarkBackground()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "D4B896"))
                .frame(width: size, height: size)

            if let img = processedImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size * 0.65, height: size * 0.65)
            }
        }
    }
}

// MARK: - GreetingBubble
struct GreetingBubble: View {
    let state: RichardState
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            RichardAvatar(state: state, size: 40)
            Text("안녕~! 나 리처드야아~\n무슨 일 있어~? 그래유!")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "5C4A32"))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "D4B896"))
                )
            Spacer()
        }
    }
}

// MARK: - MessageBubble
struct MessageBubble: View {
    let message: ChatMessage
    let richardBubble: Color
    let userBubble: Color
    let dark: Color
    let state: RichardState

    var isFromRichard: Bool { message.role == .richard }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromRichard {
                RichardAvatar(state: state, size: 36)
            } else {
                Spacer()
            }

            Text(message.content)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(isFromRichard ? dark : .white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFromRichard ? richardBubble : userBubble)
                )

            if !isFromRichard {
                Spacer(minLength: 44)
            }
        }
    }
}

// MARK: - RichardTypingIndicator
struct RichardTypingIndicator: View {
    let state: RichardState
    let bubbleColor: Color
    let dark: Color
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            RichardAvatar(state: state, size: 36)
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(dark.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(bubbleColor))
            Spacer()
        }
        .onAppear { animating = true }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppStateViewModel())
}
