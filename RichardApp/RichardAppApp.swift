import SwiftUI

@main
struct RichardAppApp: App {
    @StateObject private var appState = AppStateViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
