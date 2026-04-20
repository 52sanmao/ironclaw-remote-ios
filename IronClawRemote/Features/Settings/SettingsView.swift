import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingConnectionSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    LabeledContent("Name", value: appState.gatewayConfiguration.name)
                    LabeledContent("Base URL", value: appState.gatewayConfiguration.baseURL.absoluteString)
                    if appState.gatewayConfiguration.isDemoMode {
                        Text("Demo mode is active. Connect a live gateway here when you want real backend data.")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    Button("Edit Connection") {
                        showingConnectionSheet = true
                    }
                    Button("Test Connection") {
                        Task { await appState.refreshProfile() }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { appState.preferredTheme },
                        set: { appState.preferredTheme = $0 }
                    )) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                }

                Section("Profile") {
                    if let profile = appState.session.profile {
                        LabeledContent("Name", value: profile.displayName)
                        if let email = profile.email {
                            LabeledContent("Email", value: email)
                        }
                        if let role = profile.role {
                            LabeledContent("Role", value: role)
                        }
                    } else {
                        Text(appState.session.lastErrorMessage ?? "No profile loaded yet.")
                            .foregroundStyle(ICColor.textSecondary)
                    }
                }

                Section("About") {
                    Text("IronClaw Remote is a native iOS controller for the IronClaw gateway.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingConnectionSheet) {
                GatewayConnectionView()
            }
        }
    }
}
