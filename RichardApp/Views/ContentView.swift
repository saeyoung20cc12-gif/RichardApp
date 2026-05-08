import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppStateViewModel

    var body: some View {
        MainRoomView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStateViewModel())
}
