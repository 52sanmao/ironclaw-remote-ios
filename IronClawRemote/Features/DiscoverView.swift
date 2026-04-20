import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.flexible(), spacing: ICSpacing.md),
        GridItem(.flexible(), spacing: ICSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ICSpacing.md) {
                    gatewayOverviewCard
                    quickActionsSection
                    capabilitiesSection
                }
                .padding(ICSpacing.md)
            }
            .navigationTitle("发现")
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

            if let profile = appState.session.profile {
                Divider()
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
                Divider()
                Text(appState.session.lastErrorMessage ?? "连接网关后即可使用聊天、工作区和活动工具。")
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }

            HStack(spacing: ICSpacing.sm) {
                Button("测试连接") {
                    Task { await appState.refreshProfile() }
                }
                .buttonStyle(.borderedProminent)

                Button("打开设置") {
                    appState.selectedTab = .settings
                }
                .buttonStyle(.bordered)
            }
        }
        .icCard()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("快捷操作")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: ICSpacing.md) {
                quickActionCard(
                    title: "聊天",
                    subtitle: "继续会话并查看实时回复。",
                    systemImage: "message.badge.waveform",
                    action: { appState.selectedTab = .chat }
                )
                quickActionCard(
                    title: "工作区",
                    subtitle: "搜索并预览记忆文件。",
                    systemImage: "folder",
                    action: { appState.selectedTab = .workspace }
                )
                quickActionCard(
                    title: "活动",
                    subtitle: "查看任务、例程和使命。",
                    systemImage: "waveform.path.ecg",
                    action: { appState.selectedTab = .activity }
                )
                quickActionCard(
                    title: "设置",
                    subtitle: "更新网关地址、令牌和主题。",
                    systemImage: "gearshape",
                    action: { appState.selectedTab = .settings }
                )
            }
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("网关能力")
                .font(.title3.bold())

            capabilityRow(
                title: "原生聊天控制",
                detail: "在 iOS 上直接流式查看助手回复、检查实时事件并处理审批。",
                systemImage: "bubble.left.and.bubble.right.fill"
            )
            capabilityRow(
                title: "工作区记忆浏览",
                detail: "读取记忆文件，并从搜索结果直接跳转到预览。",
                systemImage: "doc.text.magnifyingglass"
            )
            capabilityRow(
                title: "运行活动总览",
                detail: "用摘要卡片和详情视图跟踪任务、例程和使命。",
                systemImage: "chart.bar.xaxis"
            )
        }
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

    private func capabilityRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: ICSpacing.sm) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(ICColor.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ICColor.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }
            Spacer()
        }
        .icCard()
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
