import SwiftUI

struct ActivityHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !hasPrimaryContent {
                    ContentUnavailableView("正在加载活动…", systemImage: "bolt.horizontal.circle")
                } else if let errorMessage = viewModel.errorMessage, !hasPrimaryContent {
                    ContentUnavailableView(
                        "无法加载活动",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: ICSpacing.md) {
                            summarySection
                            if let errorMessage = viewModel.errorMessage {
                                statusNotice(
                                    title: "刷新失败",
                                    message: errorMessage,
                                    color: ICColor.danger,
                                    icon: "exclamationmark.triangle.fill"
                                )
                            }
                            jobsSection
                            routinesSection
                            missionsSection
                        }
                        .padding(ICSpacing.md)
                    }
                }
            }
            .navigationTitle("活动")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load(using: appState.gatewayConfiguration) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.load(using: appState.gatewayConfiguration)
            }
        }
    }

    private var hasPrimaryContent: Bool {
        !viewModel.jobs.isEmpty || !viewModel.routines.isEmpty || !viewModel.missions.isEmpty
    }

    private var summarySection: some View {
        HStack(spacing: ICSpacing.md) {
            summaryCard(
                title: "任务",
                value: "\(viewModel.jobs.count)",
                icon: "shippingbox",
                destination: ActivityCollectionView(title: "任务") {
                    if viewModel.jobs.isEmpty {
                        emptyCard("当前没有可用任务。")
                    } else {
                        ForEach(viewModel.jobs) { job in
                            jobCard(job)
                        }
                    }
                }
            )

            summaryCard(
                title: "例程",
                value: "\(viewModel.routines.count)",
                icon: "clock.arrow.circlepath",
                destination: ActivityCollectionView(title: "例程") {
                    if viewModel.routines.isEmpty {
                        emptyCard("当前没有可用例程。")
                    } else {
                        ForEach(viewModel.routines) { routine in
                            routineCard(routine)
                        }
                    }
                }
            )

            summaryCard(
                title: "使命",
                value: "\(viewModel.missions.count)",
                icon: "flag.pattern.checkered",
                destination: ActivityCollectionView(title: "使命") {
                    if let missionsErrorMessage = viewModel.missionsErrorMessage {
                        statusNotice(
                            title: "使命不可用",
                            message: missionsErrorMessage,
                            color: ICColor.warning,
                            icon: "flag.slash.fill"
                        )
                    }
                    if viewModel.missions.isEmpty {
                        emptyCard("当前网关没有可用使命。")
                    } else {
                        ForEach(viewModel.missions) { mission in
                            missionCard(mission)
                        }
                    }
                }
            )
        }
    }

    private var jobsSection: some View {
        section(
            "任务",
            destination: ActivityCollectionView(title: "任务") {
                if viewModel.jobs.isEmpty {
                    emptyCard("当前没有可用任务。")
                } else {
                    ForEach(viewModel.jobs) { job in
                        jobCard(job)
                    }
                }
            }
        ) {
            if viewModel.jobs.isEmpty {
                emptyCard("当前没有可用任务。")
            } else {
                ForEach(viewModel.jobs.prefix(5)) { job in
                    jobCard(job)
                }
            }
        }
    }

    private var routinesSection: some View {
        section(
            "例程",
            destination: ActivityCollectionView(title: "例程") {
                if viewModel.routines.isEmpty {
                    emptyCard("当前没有可用例程。")
                } else {
                    ForEach(viewModel.routines) { routine in
                        routineCard(routine)
                    }
                }
            }
        ) {
            if viewModel.routines.isEmpty {
                emptyCard("当前没有可用例程。")
            } else {
                ForEach(viewModel.routines.prefix(5)) { routine in
                    routineCard(routine)
                }
            }
        }
    }

    private var missionsSection: some View {
        section(
            "使命",
            destination: ActivityCollectionView(title: "使命") {
                if let missionsErrorMessage = viewModel.missionsErrorMessage {
                    statusNotice(
                        title: "使命不可用",
                        message: missionsErrorMessage,
                        color: ICColor.warning,
                        icon: "flag.slash.fill"
                    )
                }
                if viewModel.missions.isEmpty {
                    emptyCard("当前网关没有可用使命。")
                } else {
                    ForEach(viewModel.missions) { mission in
                        missionCard(mission)
                    }
                }
            }
        ) {
            if let missionsErrorMessage = viewModel.missionsErrorMessage {
                statusNotice(
                    title: "使命不可用",
                    message: missionsErrorMessage,
                    color: ICColor.warning,
                    icon: "flag.slash.fill"
                )
            }
            if viewModel.missions.isEmpty {
                emptyCard("当前网关没有可用使命。")
            } else {
                ForEach(viewModel.missions.prefix(5)) { mission in
                    missionCard(mission)
                }
            }
        }
    }

    private func summaryCard<Destination: View>(title: String, value: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: ICSpacing.xs) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(ICColor.textPrimary)
                Text("打开")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ICColor.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View, Destination: View>(_ title: String, destination: Destination, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                NavigationLink("查看全部", destination: destination)
                    .font(.caption.weight(.semibold))
            }
            content()
        }
    }

    private func jobCard(_ job: JobSummary) -> some View {
        NavigationLink(destination: JobDetailView(job: job)) {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                HStack(alignment: .top, spacing: ICSpacing.sm) {
                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                        Text(job.title ?? job.id)
                            .font(.headline)
                            .foregroundStyle(ICColor.textPrimary)
                        if let source = job.source, !source.isEmpty {
                            Label(source, systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                    }
                    Spacer()
                    statusBadge(Self.localizedStatusTitle(job.status), color: statusColor(for: job.status))
                }

                if let createdAt = job.createdAt, !createdAt.isEmpty {
                    Label(createdAt, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func routineCard(_ routine: RoutineSummary) -> some View {
        NavigationLink(destination: RoutineDetailView(routine: routine)) {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                HStack(alignment: .top, spacing: ICSpacing.sm) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundStyle(ICColor.textPrimary)
                    Spacer()
                    if let status = routine.status, !status.isEmpty {
                        statusBadge(Self.localizedStatusTitle(status), color: statusColor(for: status))
                    }
                }

                if let trigger = routine.trigger, !trigger.isEmpty {
                    Label(trigger, systemImage: "bolt.badge.clock")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func missionCard(_ mission: MissionSummary) -> some View {
        NavigationLink(destination: MissionDetailView(mission: mission)) {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                HStack(alignment: .top, spacing: ICSpacing.sm) {
                    Text(mission.name)
                        .font(.headline)
                        .foregroundStyle(ICColor.textPrimary)
                    Spacer()
                    if let status = mission.status, !status.isEmpty {
                        statusBadge(Self.localizedStatusTitle(status), color: statusColor(for: status))
                    }
                }

                Text(mission.goal ?? "未提供使命目标。")
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .icCard()
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(ICColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .icCard()
    }

    private func statusNotice(title: String, message: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: ICSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ICColor.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .icCard()
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private static func localizedStatusTitle(_ status: String) -> String {
        switch status.lowercased() {
        case "running", "active", "streaming":
            return "运行中"
        case "succeeded", "success", "completed", "ready":
            return "已完成"
        case "waiting", "queued", "paused", "pending":
            return "等待中"
        case "failed", "error", "cancelled", "canceled":
            return "失败"
        default:
            return status
        }
    }

    private func statusColor(for status: String?) -> Color {
        switch status?.lowercased() {
        case "running", "active", "streaming", "succeeded", "success", "completed", "ready":
            return ICColor.success
        case "waiting", "queued", "paused", "pending":
            return ICColor.warning
        case "failed", "error", "cancelled", "canceled":
            return ICColor.danger
        default:
            return ICColor.textSecondary
        }
    }

    private struct ActivityCollectionView<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: ICSpacing.md) {
                    content()
                }
                .padding(ICSpacing.md)
            }
            .navigationTitle(title)
        }
    }

    private struct JobDetailView: View {
        let job: JobSummary

        var body: some View {
            List {
                Section("概览") {
                    LabeledContent("标题", value: job.title ?? job.id)
                    LabeledContent("状态", value: localizedStatusTitle(job.status))
                    if let source = job.source, !source.isEmpty {
                        LabeledContent("来源", value: source)
                    }
                    if let createdAt = job.createdAt, !createdAt.isEmpty {
                        LabeledContent("创建时间", value: createdAt)
                    }
                }

                Section("标识") {
                    Text(job.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(job.title ?? "任务")
        }

        private func localizedStatusTitle(_ status: String) -> String {
            ActivityHomeView.localizedStatusTitle(status)
        }
    }

    private struct RoutineDetailView: View {
        let routine: RoutineSummary

        var body: some View {
            List {
                Section("概览") {
                    LabeledContent("名称", value: routine.name)
                    if let status = routine.status, !status.isEmpty {
                        LabeledContent("状态", value: localizedStatusTitle(status))
                    }
                    if let trigger = routine.trigger, !trigger.isEmpty {
                        LabeledContent("触发条件", value: trigger)
                    }
                }

                Section("标识") {
                    Text(routine.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(routine.name)
        }

        private func localizedStatusTitle(_ status: String) -> String {
            ActivityHomeView.localizedStatusTitle(status)
        }
    }

    private struct MissionDetailView: View {
        let mission: MissionSummary

        var body: some View {
            List {
                Section("概览") {
                    LabeledContent("名称", value: mission.name)
                    if let status = mission.status, !status.isEmpty {
                        LabeledContent("状态", value: localizedStatusTitle(status))
                    }
                    if let goal = mission.goal, !goal.isEmpty {
                        Text(goal)
                    } else {
                        Text("未提供使命目标。")
                            .foregroundStyle(ICColor.textSecondary)
                    }
                }

                Section("标识") {
                    Text(mission.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(mission.name)
        }

        private func localizedStatusTitle(_ status: String) -> String {
            ActivityHomeView.localizedStatusTitle(status)
        }
    }
}
