import SwiftUI

@main
struct IronClawRemoteApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}
