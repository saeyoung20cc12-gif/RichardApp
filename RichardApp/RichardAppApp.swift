import SwiftUI

@main
struct RichardAppApp: App {
    @StateObject private var appState = AppStateViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task { @MainActor in
                switch newPhase {
                case .active:
                    LiveActivityService.shared.handleForeground()
                case .background, .inactive:
                    LiveActivityService.shared.handleBackground()
                @unknown default:
                    break
                }
            }
        }
    }
}
