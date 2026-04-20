import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )) {
            ChatHomeView()
                .tabItem {
                    Label(AppTab.chat.title, systemImage: AppTab.chat.systemImage)
                }
                .tag(AppTab.chat)

            WorkspaceView()
                .tabItem {
                    Label(AppTab.workspace.title, systemImage: AppTab.workspace.systemImage)
                }
                .tag(AppTab.workspace)

            ActivityHomeView()
                .tabItem {
                    Label(AppTab.activity.title, systemImage: AppTab.activity.systemImage)
                }
                .tag(AppTab.activity)

            DiscoverView()
                .tabItem {
                    Label(AppTab.discover.title, systemImage: AppTab.discover.systemImage)
                }
                .tag(AppTab.discover)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
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
