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
            .navigationTitle("Discover")
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
                Text(appState.session.lastErrorMessage ?? "Connect to a gateway to unlock chat, workspace, and activity tools.")
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }

            HStack(spacing: ICSpacing.sm) {
                Button("Test Connection") {
                    Task { await appState.refreshProfile() }
                }
                .buttonStyle(.borderedProminent)

                Button("Open Settings") {
                    appState.selectedTab = .settings
                }
                .buttonStyle(.bordered)
            }
        }
        .icCard()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("Quick Actions")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: ICSpacing.md) {
                quickActionCard(
                    title: "Chat",
                    subtitle: "Resume threads and live responses.",
                    systemImage: "message.badge.waveform",
                    action: { appState.selectedTab = .chat }
                )
                quickActionCard(
                    title: "Workspace",
                    subtitle: "Search and preview memory files.",
                    systemImage: "folder",
                    action: { appState.selectedTab = .workspace }
                )
                quickActionCard(
                    title: "Activity",
                    subtitle: "Inspect jobs, routines, and missions.",
                    systemImage: "waveform.path.ecg",
                    action: { appState.selectedTab = .activity }
                )
                quickActionCard(
                    title: "Settings",
                    subtitle: "Update gateway URL, token, and theme.",
                    systemImage: "gearshape",
                    action: { appState.selectedTab = .settings }
                )
            }
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Text("Gateway Capabilities")
                .font(.title3.bold())

            capabilityRow(
                title: "Native chat control",
                detail: "Stream assistant replies, inspect live events, and resolve gates without leaving iOS.",
                systemImage: "bubble.left.and.bubble.right.fill"
            )
            capabilityRow(
                title: "Workspace memory browsing",
                detail: "Read memory files and jump from search results straight into previews.",
                systemImage: "doc.text.magnifyingglass"
            )
            capabilityRow(
                title: "Operational activity",
                detail: "Track jobs, routines, and missions with summary cards and drill-down detail views.",
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
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .degraded:
            return "Degraded"
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
