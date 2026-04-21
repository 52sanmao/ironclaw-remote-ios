import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingConnectionSheet = false
    @State private var path: [ConsoleRoute] = []

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: ICSpacing.lg) {
                    connectionCard

                    featureGroup(title: "资源", icon: "folder", color: ICColor.accent, routes: [.workspace])
                    featureGroup(title: "运行", icon: "waveform.path.ecg", color: ICColor.success, routes: [.activity])
                    featureGroup(title: "能力", icon: "puzzlepiece.extension", color: ICColor.warning, routes: [.extensions, .skills])
                    featureGroup(title: "账户与网关", icon: "person.crop.circle", color: ICColor.textPrimary, routes: [.profile, .tokens, .gatewayStatus, .logs, .settings])

                    if isAdmin {
                        featureGroup(title: "管理员", icon: "lock.shield", color: ICColor.danger, routes: [.adminUsers, .adminUsage, .adminSecrets, .pairing])
                    }
                }
                .padding(ICSpacing.md)
            }
            .background(ICColor.background)
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

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                    Text(appState.gatewayConfiguration.name)
                        .font(.headline)
                    Text(appState.gatewayConfiguration.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                connectionStatusDot
            }

            if let profile = appState.session.profile {
                Divider()
                HStack(spacing: ICSpacing.sm) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ICColor.accent)
                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                        Text(profile.displayName)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: ICSpacing.xs) {
                            if let role = profile.role, !role.isEmpty {
                                ConsoleBadge(text: role, color: role.lowercased() == "admin" ? ICColor.accent : ICColor.textSecondary)
                            }
                            if let email = profile.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                }
            } else if let error = appState.session.lastErrorMessage {
                Divider()
                HStack(spacing: ICSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ICColor.danger)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                        .lineLimit(2)
                    Spacer()
                }
            }

            HStack(spacing: ICSpacing.sm) {
                Button {
                    showingConnectionSheet = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await appState.refreshProfile() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var connectionStatusDot: some View {
        HStack(spacing: ICSpacing.xxs) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(connectionStatusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(connectionStatusColor)
        }
    }

    private var connectionStatusColor: Color {
        switch appState.session.connectionStatus {
        case .connected: return ICColor.success
        case .connecting: return ICColor.warning
        case .degraded: return ICColor.danger
        case .disconnected: return ICColor.textSecondary
        }
    }

    private var connectionStatusText: String {
        switch appState.session.connectionStatus {
        case .connected: return "在线"
        case .connecting: return "连接中"
        case .degraded: return "异常"
        case .disconnected: return "离线"
        }
    }

    private func featureGroup(title: String, icon: String, color: Color, routes: [ConsoleRoute]) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)

            LazyVGrid(columns: columns, spacing: ICSpacing.sm) {
                ForEach(routes) { route in
                    NavigationLink(value: route) {
                        featureCard(route: route)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func featureCard(route: ConsoleRoute) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.xs) {
            Image(systemName: route.systemImage)
                .font(.title2)
                .foregroundStyle(routeIconColor(route))
                .frame(width: 40, height: 40)
                .background(routeIconColor(route).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))

            Text(route.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ICColor.textPrimary)

            Text(routeSubtitle(route))
                .font(.caption2)
                .foregroundStyle(ICColor.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func routeIconColor(_ route: ConsoleRoute) -> Color {
        switch route {
        case .workspace: return ICColor.accent
        case .activity: return ICColor.success
        case .extensions: return ICColor.warning
        case .skills: return Color.purple
        case .tokens: return Color.yellow
        case .gatewayStatus: return Color.cyan
        case .settings: return ICColor.textSecondary
        case .profile: return ICColor.accent
        case .logs: return ICColor.textSecondary
        case .adminUsers: return ICColor.danger
        case .adminUsage: return ICColor.warning
        case .adminSecrets: return Color.pink
        case .pairing: return Color.teal
        }
    }

    private func routeSubtitle(_ route: ConsoleRoute) -> String {
        switch route {
        case .workspace: return "浏览与编辑"
        case .activity: return "任务与例程"
        case .extensions: return "扩展管理"
        case .skills: return "技能目录"
        case .tokens: return "API 令牌"
        case .gatewayStatus: return "运行状态"
        case .settings: return "配置项"
        case .profile: return "个人信息"
        case .logs: return "日志流"
        case .adminUsers: return "用户管理"
        case .adminUsage: return "用量统计"
        case .adminSecrets: return "密钥管理"
        case .pairing: return "设备审批"
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
