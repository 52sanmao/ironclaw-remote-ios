import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingConnectionSheet = false
    @State private var path: [ConsoleRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                profileSection
                consoleSection(
                    title: "资源",
                    routes: [.workspace]
                )
                consoleSection(
                    title: "运行",
                    routes: [.activity]
                )
                consoleSection(
                    title: "能力",
                    routes: [.extensions, .skills]
                )
                consoleSection(
                    title: "账户与网关",
                    routes: [.profile, .tokens, .gatewayStatus, .logs, .settings]
                )
                if isAdmin {
                    consoleSection(
                        title: "管理员",
                        routes: [.adminUsers, .adminUsage, .adminSecrets, .pairing]
                    )
                }
            }
            .navigationTitle("控制台")
            .sheet(isPresented: $showingConnectionSheet) {
                GatewayConnectionView()
            }
            .navigationDestination(for: ConsoleRoute.self) { route in
                destination(for: route)
            }
            .onChange(of: appState.pendingConsoleRoute) { _, newValue in
                guard let newValue else { return }
                path = [newValue]
                appState.pendingConsoleRoute = nil
            }
        }
    }

    private var isAdmin: Bool {
        (appState.session.profile?.role ?? "").lowercased() == "admin"
    }

    private var profileSection: some View {
        Section("当前连接") {
            VStack(alignment: .leading, spacing: ICSpacing.xs) {
                Text(appState.gatewayConfiguration.name)
                    .font(.headline)
                Text(appState.gatewayConfiguration.baseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .textSelection(.enabled)
                if let profile = appState.session.profile {
                    Divider()
                    Text(profile.displayName)
                        .font(.subheadline.weight(.medium))
                    if let role = profile.role, !role.isEmpty {
                        Label(role, systemImage: "briefcase")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    if let email = profile.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                } else if let error = appState.session.lastErrorMessage {
                    Divider()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }
            Button("编辑连接") {
                showingConnectionSheet = true
            }
            Button("刷新资料") {
                Task { await appState.refreshProfile() }
            }
        }
    }

    private func consoleSection(title: String, routes: [ConsoleRoute]) -> some View {
        Section(title) {
            ForEach(routes) { route in
                NavigationLink(value: route) {
                    Label(route.title, systemImage: route.systemImage)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ConsoleRoute) -> some View {
        switch route {
        case .workspace:
            WorkspaceView()
        case .activity:
            ActivityHomeView()
        case .extensions:
            ExtensionsView()
        case .skills:
            SkillsView()
        case .tokens:
            TokensView()
        case .gatewayStatus:
            GatewayStatusView()
        case .settings:
            ConsolePreferencesView(showingConnectionSheet: $showingConnectionSheet)
        case .adminUsers:
            AdminUsersView()
        case .adminUsage:
            AdminUsageView()
        case .profile:
            ProfileView()
        case .logs:
            LogsView()
        case .adminSecrets:
            AdminSecretsView()
        case .pairing:
            PairingView()
        }
    }
}
