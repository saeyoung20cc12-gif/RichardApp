import SwiftUI

// MARK: - ChatView
/// Full-screen chat interface for talking to Richard.
/// Phase 2 will wire this up to LLMService for real AI responses.
struct ChatView: View {
    @EnvironmentObject var appState: AppStateViewModel
    @Environment(\.dismiss) var dismiss

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "1B5E40"), Color(hex: "0A2E1F")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Chat messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Greeting message
                                if appState.chatMessages.isEmpty {
                                    GreetingBubble()
                                        .padding(.top, 16)
                                }

                                ForEach(appState.chatMessages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if appState.isLoading {
                                    TypingIndicator()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        .onChange(of: appState.chatMessages.count) { _, _ in
                            if let last = appState.chatMessages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
                                    .fill(.white.opacity(0.12))
                            )
                            .foregroundColor(.white)
                            .focused($isInputFocused)

                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .white)
                                .font(.system(size: 20))
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                              ? Color.white.opacity(0.1)
                                              : Color(hex: "4CAF7D"))
                                )
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || appState.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.6))
                }
            }
            .navigationTitle("리처드 🦆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendMessage(text)
    }
}

// MARK: - GreetingBubble
struct GreetingBubble: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("🦆")
                .font(.system(size: 32))
            Text("안녕~! 나 리처드야아~\n무슨 일 있어~? 그래유!")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "2E7D52"))
                )
            Spacer()
        }
    }
}

// MARK: - MessageBubble
struct MessageBubble: View {
    let message: ChatMessage

    var isFromRichard: Bool { message.role == .richard }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromRichard {
                Text("🦆").font(.system(size: 28))
            } else {
                Spacer()
            }

            Text(message.content)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFromRichard ? Color(hex: "2E7D52") : Color(hex: "1565C0"))
                )

            if !isFromRichard {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - TypingIndicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("🦆").font(.system(size: 28))
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "2E7D52")))
            Spacer()
        }
        .onAppear { animating = true }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppStateViewModel())
}
