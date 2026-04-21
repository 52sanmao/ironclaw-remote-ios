import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )) {
            DiscoverView()
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
                }
                .tag(AppTab.dashboard)

            ChatHomeView()
                .tabItem {
                    Label(AppTab.chat.title, systemImage: AppTab.chat.systemImage)
                }
                .tag(AppTab.chat)

            SettingsView()
                .tabItem {
                    Label(AppTab.console.title, systemImage: AppTab.console.systemImage)
                }
                .tag(AppTab.console)
        }
        .tint(ICColor.accent)
        .task {
            if appState.session.profile == nil,
               (!appState.gatewayConfiguration.token.isEmpty || appState.gatewayConfiguration.isDemoMode) {
                await appState.refreshProfile()
            }
        }
    }
}
