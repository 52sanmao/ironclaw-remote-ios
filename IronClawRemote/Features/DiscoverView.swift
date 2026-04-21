import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var chatViewModel = ChatViewModel()
    @State private var activityViewModel = ActivityViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: ICSpacing.md),
        GridItem(.flexible(), spacing: ICSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ICSpacing.md) {
                    gatewayOverviewCard
                    dashboardHighlightsSection
                    quickActionsSection
                    adminSection
                }
                .padding(ICSpacing.md)
            }
            .background(ICColor.background)
            .navigationTitle("工作台")
            .task {
                if chatViewModel.threads.isEmpty, chatViewModel.assistantThread == nil {
                    await chatViewModel.load(using: appState.gatewayConfiguration)
                }
                if activityViewModel.jobs.isEmpty, activityViewModel.routines.isEmpty, activityViewModel.missions.isEmpty {
                    await activityViewModel.load(using: appState.gatewayConfiguration)
                }
            }
            .refreshable {
                await appState.refreshProfile()
                await chatViewModel.load(using: appState.gatewayConfiguration)
                await activityViewModel.load(using: appState.gatewayConfiguration)
            }
        }
    }

    private var gatewayOverviewCard: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack(alignment: .top, spacing: ICSpacing.sm) {
                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                    Text(appState.gatewayConfiguration.name)
                        .font(.title3.bold())
                        .foregroundStyle(ICColor.textPrimary)
                    Text(appState.gatewayConfiguration.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                        .textSelection(.enabled)
                }
                Spacer()
                statusBadge(appState.session.connectionStatus)
            }

            Divider()

            if let profile = appState.session.profile {
                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                    Label(profile.displayName, systemImage: "person.crop.circle.fill")
                        .foregroundStyle(ICColor.textPrimary)
                    if let email = profile.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    if let role = profile.role, !role.isEmpty {
                        Label(role, systemImage: "briefcase")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                }
            } else {
                Text(appState.session.lastErrorMessage ?? "连接网关后即可使用控制台功能。")
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }

            HStack(spacing: ICSpacing.sm) {
                Button("测试连接") {
                    Task { await appState.refreshProfile() }
                }
                .buttonStyle(.borderedProminent)

                Button("打开控制台") {
                    appState.selectedTab = .console
                }
                .buttonStyle(.bordered)
            }
        }
        .icCard()
    }

    private var dashboardHighlightsSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("今日重点")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: ICSpacing.md) {
                metricCard(
                    title: "会话",
                    value: "\(threadCount)",
                    subtitle: latestThreadTitle,
                    systemImage: "message.badge.waveform",
                    actionTitle: "进入对话"
                ) {
                    appState.selectedTab = .chat
                }

                metricCard(
                    title: "任务",
                    value: "\(activityViewModel.jobs.count)",
                    subtitle: activitySubtitle(for: activityViewModel.jobs.first?.title),
                    systemImage: "shippingbox",
                    actionTitle: "查看运行中心"
                ) {
                    appState.openConsole(.activity)
                }

                metricCard(
                    title: "例程",
                    value: "\(activityViewModel.routines.count)",
                    subtitle: activitySubtitle(for: activityViewModel.routines.first?.name),
                    systemImage: "clock.arrow.circlepath",
                    actionTitle: "管理例程"
                ) {
                    appState.openConsole(.activity)
                }

                metricCard(
                    title: "使命",
                    value: "\(activityViewModel.missions.count)",
                    subtitle: activityViewModel.missionsErrorMessage ?? activitySubtitle(for: activityViewModel.missions.first?.name),
                    systemImage: "flag.pattern.checkered",
                    actionTitle: "打开使命"
                ) {
                    appState.openConsole(.activity)
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("快捷入口")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: ICSpacing.md) {
                quickActionCard(title: "工作区", subtitle: "浏览、搜索和预览记忆文件。", systemImage: "folder") {
                    appState.openConsole(.workspace)
                }
                quickActionCard(title: "扩展", subtitle: "查看已安装扩展与状态。", systemImage: "puzzlepiece.extension") {
                    appState.openConsole(.extensions)
                }
                quickActionCard(title: "技能", subtitle: "搜索和安装 skills。", systemImage: "wand.and.stars") {
                    appState.openConsole(.skills)
                }
                quickActionCard(title: "网关状态", subtitle: "查看连接、版本和模型配置。", systemImage: "antenna.radiowaves.left.and.right") {
                    appState.openConsole(.gatewayStatus)
                }
                quickActionCard(title: "令牌", subtitle: "管理 API 令牌。", systemImage: "key.fill") {
                    appState.openConsole(.tokens)
                }
                quickActionCard(title: "设置", subtitle: "管理主题、连接和设置项。", systemImage: "gearshape") {
                    appState.openConsole(.settings)
                }
            }
        }
    }

    @ViewBuilder
    private var adminSection: some View {
        if (appState.session.profile?.role ?? "").lowercased() == "admin" {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                Text("管理员")
                    .font(.title3.bold())

                VStack(spacing: ICSpacing.sm) {
                    quickRow(title: "用户管理", subtitle: "查看、创建和管理用户。", systemImage: "person.3.fill") {
                        appState.openConsole(.adminUsers)
                    }
                    quickRow(title: "用量总览", subtitle: "查看系统级用户和成本统计。", systemImage: "chart.bar.doc.horizontal") {
                        appState.openConsole(.adminUsage)
                    }
                }
            }
        }
    }

    private var threadCount: Int {
        chatViewModel.threads.count + (chatViewModel.assistantThread == nil ? 0 : 1)
    }

    private var latestThreadTitle: String {
        if let thread = chatViewModel.assistantThread {
            return thread.title ?? "助手"
        }
        if let thread = chatViewModel.threads.first {
            return thread.title ?? "最近会话"
        }
        return "暂无会话"
    }

    private func activitySubtitle(for title: String?) -> String {
        guard let title, !title.isEmpty else { return "暂无数据" }
        return title
    }

    private func metricCard(title: String, value: String, subtitle: String, systemImage: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ICColor.accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(ICColor.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
                .lineLimit(2)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .icCard()
    }

    private func quickActionCard(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(ICColor.accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ICColor.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .contentShape(Rectangle())
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func quickRow(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: ICSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(ICColor.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ICColor.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ICColor.textSecondary)
            }
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ status: ConnectionStatus) -> some View {
        Text(statusTitle(status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusTitle(_ status: ConnectionStatus) -> String {
        switch status {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .degraded:
            return "异常"
        }
    }

    private func statusColor(_ status: ConnectionStatus) -> Color {
        switch status {
        case .connected:
            return ICColor.success
        case .connecting:
            return ICColor.warning
        case .degraded:
            return ICColor.danger
        case .disconnected:
            return ICColor.textSecondary
        }
    }
}
