import SwiftUI

struct ActivityHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !hasPrimaryContent {
                    ContentUnavailableView("正在加载运行中心…", systemImage: "bolt.horizontal.circle")
                } else if let errorMessage = viewModel.errorMessage, !hasPrimaryContent {
                    ContentUnavailableView(
                        "无法加载运行中心",
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
            .navigationTitle("运行中心")
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
                subtitle: "作业、重试与文件",
                icon: "shippingbox",
                destination: JobListView(jobs: viewModel.jobs)
            )

            summaryCard(
                title: "例程",
                value: "\(viewModel.routines.count)",
                subtitle: "触发、启停与记录",
                icon: "clock.arrow.circlepath",
                destination: RoutineListView(routines: viewModel.routines)
            )

            summaryCard(
                title: "使命",
                value: "\(viewModel.missions.count)",
                subtitle: "推进与线程钻取",
                icon: "flag.pattern.checkered",
                destination: MissionListView(
                    missions: viewModel.missions,
                    missionsErrorMessage: viewModel.missionsErrorMessage
                )
            )
        }
    }

    private var jobsSection: some View {
        section(
            "任务",
            destination: JobListView(jobs: viewModel.jobs)
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
            destination: RoutineListView(routines: viewModel.routines)
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
            destination: MissionListView(
                missions: viewModel.missions,
                missionsErrorMessage: viewModel.missionsErrorMessage
            )
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

    private func summaryCard<Destination: View>(title: String, value: String, subtitle: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: ICSpacing.xs) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(ICColor.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(ICColor.textSecondary)
                    .lineLimit(2)
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
            ActivityRowCard(
                title: job.title ?? job.id,
                subtitle: job.source,
                badgeText: Self.localizedStatusTitle(job.status),
                badgeColor: statusColor(for: job.status),
                lines: [job.createdAt].compactMap { line in
                    guard let line, !line.isEmpty else { return nil }
                    return ("clock", line)
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func routineCard(_ routine: RoutineSummary) -> some View {
        NavigationLink(destination: RoutineDetailView(routine: routine)) {
            ActivityRowCard(
                title: routine.name,
                subtitle: routine.description,
                badgeText: Self.localizedStatusTitle(routine.status ?? "unknown"),
                badgeColor: statusColor(for: routine.status),
                lines: [routine.trigger].compactMap { line in
                    guard let line, !line.isEmpty else { return nil }
                    return ("bolt.badge.clock", line)
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func missionCard(_ mission: MissionSummary) -> some View {
        NavigationLink(destination: MissionDetailView(mission: mission)) {
            ActivityRowCard(
                title: mission.name,
                subtitle: mission.currentFocus ?? mission.goal,
                badgeText: Self.localizedStatusTitle(mission.status ?? "unknown"),
                badgeColor: statusColor(for: mission.status),
                lines: [mission.cadenceDescription, mission.goal].compactMap { line in
                    guard let line, !line.isEmpty else { return nil }
                    return ("text.alignleft", line)
                }
            )
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

    static func localizedStatusTitle(_ status: String) -> String {
        switch status.lowercased() {
        case "running", "active", "streaming", "in_progress":
            return "运行中"
        case "succeeded", "success", "completed", "ready", "ok":
            return "已完成"
        case "waiting", "queued", "paused", "pending", "disabled", "unverified":
            return "等待中"
        case "failed", "error", "cancelled", "canceled", "failing":
            return "失败"
        default:
            return status
        }
    }

    private func statusColor(for status: String?) -> Color {
        switch status?.lowercased() {
        case "running", "active", "streaming", "in_progress", "succeeded", "success", "completed", "ready", "ok":
            return ICColor.success
        case "waiting", "queued", "paused", "pending", "disabled", "unverified":
            return ICColor.warning
        case "failed", "error", "cancelled", "canceled", "failing":
            return ICColor.danger
        default:
            return ICColor.textSecondary
        }
    }
}

private struct ActivityRowCard: View {
    let title: String
    let subtitle: String?
    let badgeText: String
    let badgeColor: Color
    let lines: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack(alignment: .top, spacing: ICSpacing.sm) {
                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ICColor.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label(line.1, systemImage: line.0)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .icCard()
    }
}

private struct JobListView: View {
    let jobs: [JobSummary]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                if jobs.isEmpty {
                    Text("当前没有可用任务。")
                        .foregroundStyle(ICColor.textSecondary)
                        .icCard()
                } else {
                    ForEach(jobs) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            ActivityRowCard(
                                title: job.title ?? job.id,
                                subtitle: job.source,
                                badgeText: ActivityHomeView.localizedStatusTitle(job.status),
                                badgeColor: statusColor(job.status),
                                lines: [job.createdAt, job.startedAt].compactMap { line in
                                    guard let line, !line.isEmpty else { return nil }
                                    return ("clock", line)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(ICSpacing.md)
        }
        .navigationTitle("任务")
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "running", "active", "streaming", "in_progress", "succeeded", "success", "completed", "ready", "ok": return ICColor.success
        case "waiting", "queued", "paused", "pending", "disabled", "unverified": return ICColor.warning
        case "failed", "error", "cancelled", "canceled", "failing": return ICColor.danger
        default: return ICColor.textSecondary
        }
    }
}

private struct RoutineListView: View {
    let routines: [RoutineSummary]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                if routines.isEmpty {
                    Text("当前没有可用例程。")
                        .foregroundStyle(ICColor.textSecondary)
                        .icCard()
                } else {
                    ForEach(routines) { routine in
                        NavigationLink(destination: RoutineDetailView(routine: routine)) {
                            ActivityRowCard(
                                title: routine.name,
                                subtitle: routine.description,
                                badgeText: ActivityHomeView.localizedStatusTitle(routine.status ?? "unknown"),
                                badgeColor: statusColor(routine.status),
                                lines: [routine.trigger].compactMap { line in
                                    guard let line, !line.isEmpty else { return nil }
                                    return ("bolt.badge.clock", line)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(ICSpacing.md)
        }
        .navigationTitle("例程")
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "running", "active", "streaming", "in_progress", "succeeded", "success", "completed", "ready", "ok": return ICColor.success
        case "waiting", "queued", "paused", "pending", "disabled", "unverified": return ICColor.warning
        case "failed", "error", "cancelled", "canceled", "failing": return ICColor.danger
        default: return ICColor.textSecondary
        }
    }
}

private struct MissionListView: View {
    let missions: [MissionSummary]
    let missionsErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                if let missionsErrorMessage {
                    HStack(alignment: .top, spacing: ICSpacing.sm) {
                        Image(systemName: "flag.slash.fill")
                            .foregroundStyle(ICColor.warning)
                        Text(missionsErrorMessage)
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    .icCard()
                }

                if missions.isEmpty {
                    Text("当前网关没有可用使命。")
                        .foregroundStyle(ICColor.textSecondary)
                        .icCard()
                } else {
                    ForEach(missions) { mission in
                        NavigationLink(destination: MissionDetailView(mission: mission)) {
                            ActivityRowCard(
                                title: mission.name,
                                subtitle: mission.currentFocus ?? mission.goal,
                                badgeText: ActivityHomeView.localizedStatusTitle(mission.status ?? "unknown"),
                                badgeColor: statusColor(mission.status),
                                lines: [mission.cadenceDescription, mission.goal].compactMap { line in
                                    guard let line, !line.isEmpty else { return nil }
                                    return ("text.alignleft", line)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(ICSpacing.md)
        }
        .navigationTitle("使命")
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "running", "active", "streaming", "in_progress", "succeeded", "success", "completed", "ready", "ok": return ICColor.success
        case "waiting", "queued", "paused", "pending", "disabled", "unverified": return ICColor.warning
        case "failed", "error", "cancelled", "canceled", "failing": return ICColor.danger
        default: return ICColor.textSecondary
        }
    }
}

private struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    let job: JobSummary

    @State private var detail: JobDetailResponse?
    @State private var events: [JobEventInfo] = []
    @State private var files: [ProjectFileEntry] = []
    @State private var selectedDirectory = ""
    @State private var selectedFile: ProjectFileReadResponse?
    @State private var promptText = ""
    @State private var actionMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSendingPrompt = false
    @State private var busyAction: String?

    var body: some View {
        List {
            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("概览") {
                LabeledContent("标题", value: detail?.title ?? job.title ?? job.id)
                LabeledContent("状态", value: ActivityHomeView.localizedStatusTitle(detail?.state ?? job.status))
                if let source = job.source, !source.isEmpty {
                    LabeledContent("来源", value: source)
                }
                if let createdAt = detail?.createdAt ?? job.createdAt, !createdAt.isEmpty {
                    LabeledContent("创建时间", value: createdAt)
                }
                if let startedAt = detail?.startedAt, !startedAt.isEmpty {
                    LabeledContent("开始时间", value: startedAt)
                }
                if let completedAt = detail?.completedAt, !completedAt.isEmpty {
                    LabeledContent("完成时间", value: completedAt)
                }
                if let elapsedSecs = detail?.elapsedSecs {
                    LabeledContent("耗时", value: "\(elapsedSecs) 秒")
                }
                if let jobMode = detail?.jobMode, !jobMode.isEmpty {
                    LabeledContent("模式", value: jobMode)
                }
                if let projectDir = detail?.projectDir, !projectDir.isEmpty {
                    LabeledContent("项目目录", value: projectDir)
                }
            }

            if let description = detail?.description, !description.isEmpty {
                Section("说明") {
                    Text(description)
                }
            }

            Section("操作") {
                Button(busyAction == "restart" ? "处理中…" : "重新执行") {
                    Task { await restartJob() }
                }
                .disabled(!(detail?.canRestart ?? false) || busyAction != nil)

                Button(busyAction == "cancel" ? "处理中…" : "取消任务", role: .destructive) {
                    Task { await cancelJob() }
                }
                .disabled(busyAction != nil)
            }

            if detail?.canPrompt == true {
                Section("发送跟进") {
                    TextField("继续这个任务，例如：检查失败原因并修复", text: $promptText, axis: .vertical)
                        .lineLimit(3...6)
                    Button(isSendingPrompt ? "发送中…" : "发送消息") {
                        Task { await promptJob() }
                    }
                    .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingPrompt)
                }
            }

            if let detail, !detail.transitions.isEmpty {
                Section("状态流转") {
                    ForEach(detail.transitions) { transition in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text("\(ActivityHomeView.localizedStatusTitle(transition.from)) → \(ActivityHomeView.localizedStatusTitle(transition.to))")
                                .font(.subheadline.weight(.medium))
                            Text(transition.timestamp)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                            if let reason = transition.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if detail?.projectDir != nil {
                Section("工作目录文件") {
                    if files.isEmpty {
                        Text("当前目录没有可展示的文件。")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    } else {
                        ForEach(files) { file in
                            Button {
                                Task { await selectFile(file) }
                            } label: {
                                HStack {
                                    Image(systemName: file.isDir ? "folder" : "doc.text")
                                        .foregroundStyle(file.isDir ? ICColor.warning : ICColor.accent)
                                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                        Text(file.name)
                                            .foregroundStyle(ICColor.textPrimary)
                                        Text(file.path)
                                            .font(.caption2)
                                            .foregroundStyle(ICColor.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let selectedFile {
                Section("文件预览") {
                    Text(selectedFile.path)
                        .font(.headline)
                    Text(selectedFile.content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if !events.isEmpty {
                Section("事件") {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(event.eventType)
                                .font(.subheadline.weight(.medium))
                            Text(event.createdAt)
                                .font(.caption2)
                                .foregroundStyle(ICColor.textSecondary)
                            Text(event.data.prettyText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ICColor.textSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("标识") {
                Text(job.id)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle(detail?.title ?? job.title ?? "任务")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            detail = JobDetailResponse(
                id: job.id,
                title: job.title ?? job.id,
                description: "演示模式下的任务详情。",
                state: job.status,
                userID: "demo",
                createdAt: job.createdAt ?? "",
                startedAt: job.startedAt,
                completedAt: nil,
                elapsedSecs: 42,
                projectDir: "/demo/project",
                browseURL: nil,
                jobMode: "claude_code",
                transitions: [],
                canRestart: true,
                canPrompt: true,
                jobKind: "sandbox"
            )
            events = []
            files = []
            return
        }

        do {
            async let detailRequest = appState.gatewayClient.jobDetail(id: job.id)
            async let eventsRequest = appState.gatewayClient.jobEvents(id: job.id)
            let fetchedDetail = try await detailRequest
            detail = fetchedDetail
            let fetchedEvents = try? await eventsRequest
            events = fetchedEvents?.events ?? []

            if fetchedDetail.projectDir != nil {
                let fetchedFiles = try? await appState.gatewayClient.jobFiles(id: job.id, path: selectedDirectory)
                files = fetchedFiles?.entries ?? []
            } else {
                files = []
                selectedFile = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restartJob() async {
        busyAction = "restart"
        defer { busyAction = nil }
        do {
            let result = try await appState.gatewayClient.restartJob(id: job.id)
            actionMessage = "已提交：\(result.status)"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelJob() async {
        busyAction = "cancel"
        defer { busyAction = nil }
        do {
            let result = try await appState.gatewayClient.cancelJob(id: job.id)
            actionMessage = "已提交：\(result.status)"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func promptJob() async {
        let content = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSendingPrompt = true
        defer { isSendingPrompt = false }
        do {
            let result = try await appState.gatewayClient.promptJob(id: job.id, content: content)
            actionMessage = "消息已送达：\(result.status)"
            promptText = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectFile(_ entry: ProjectFileEntry) async {
        if entry.isDir {
            selectedDirectory = entry.path
            selectedFile = nil
            do {
                let fetchedFiles = try await appState.gatewayClient.jobFiles(id: job.id, path: entry.path)
                files = fetchedFiles.entries
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        do {
            selectedFile = try await appState.gatewayClient.readJobFile(id: job.id, path: entry.path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RoutineDetailView: View {
    @Environment(AppState.self) private var appState
    let routine: RoutineSummary

    @State private var detail: RoutineDetailResponse?
    @State private var runs: [RoutineRunInfo] = []
    @State private var actionMessage: String?
    @State private var errorMessage: String?
    @State private var busyAction: String?

    var body: some View {
        List {
            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("概览") {
                LabeledContent("名称", value: detail?.name ?? routine.name)
                LabeledContent("状态", value: ActivityHomeView.localizedStatusTitle(detail?.status ?? routine.status ?? "unknown"))
                if let trigger = detail?.triggerSummary ?? routine.trigger, !trigger.isEmpty {
                    LabeledContent("触发条件", value: trigger)
                }
                if let verification = detail?.verificationStatus, !verification.isEmpty {
                    LabeledContent("验证状态", value: verification)
                }
                if let createdAt = detail?.createdAt, !createdAt.isEmpty {
                    LabeledContent("创建时间", value: createdAt)
                }
                if let nextFireAt = detail?.nextFireAt, !nextFireAt.isEmpty {
                    LabeledContent("下次触发", value: nextFireAt)
                }
                if let lastRunAt = detail?.lastRunAt, !lastRunAt.isEmpty {
                    LabeledContent("最近运行", value: lastRunAt)
                }
                if let runCount = detail?.runCount {
                    LabeledContent("运行次数", value: "\(runCount)")
                }
            }

            if let description = detail?.description, !description.isEmpty {
                Section("说明") {
                    Text(description)
                }
            }

            Section("操作") {
                Button(busyAction == "trigger" ? "处理中…" : "立即触发") {
                    Task { await triggerRoutine() }
                }
                .disabled(busyAction != nil)

                Button(busyAction == "toggle" ? "处理中…" : (detail?.enabled ?? routine.enabled ?? true ? "停用例程" : "启用例程")) {
                    Task { await toggleRoutine() }
                }
                .disabled(busyAction != nil)

                Button(busyAction == "delete" ? "处理中…" : "删除例程", role: .destructive) {
                    Task { await deleteRoutine() }
                }
                .disabled(busyAction != nil)
            }

            if let detail {
                Section("策略") {
                    jsonBlock(detail.trigger.prettyText)
                    jsonBlock(detail.action.prettyText)
                }

                Section("保护与通知") {
                    jsonBlock(detail.guardrails.prettyText)
                    jsonBlock(detail.notify.prettyText)
                }
            }

            if !runs.isEmpty {
                Section("最近运行") {
                    ForEach(runs) { run in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(ActivityHomeView.localizedStatusTitle(run.status))
                                .font(.subheadline.weight(.medium))
                            Text(run.startedAt)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                            if let completedAt = run.completedAt, !completedAt.isEmpty {
                                Text("完成于 \(completedAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            if let resultSummary = run.resultSummary, !resultSummary.isEmpty {
                                Text(resultSummary)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            if let tokensUsed = run.tokensUsed {
                                Text("Tokens：\(tokensUsed)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("标识") {
                Text(routine.id)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle(detail?.name ?? routine.name)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        errorMessage = nil

        if appState.gatewayConfiguration.isDemoMode {
            runs = []
            return
        }

        do {
            async let detailRequest = appState.gatewayClient.routineDetail(id: routine.id)
            async let runsRequest = appState.gatewayClient.routineRuns(id: routine.id)
            detail = try await detailRequest
            let fetchedRuns = try await runsRequest
            runs = fetchedRuns.runs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerRoutine() async {
        busyAction = "trigger"
        defer { busyAction = nil }
        do {
            let result = try await appState.gatewayClient.triggerRoutine(id: routine.id)
            actionMessage = "已提交：\(result.status)"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRoutine() async {
        busyAction = "toggle"
        defer { busyAction = nil }
        do {
            let enabled = !(detail?.enabled ?? routine.enabled ?? true)
            let result = try await appState.gatewayClient.toggleRoutine(id: routine.id, enabled: enabled)
            actionMessage = "已提交：\(result.status)"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRoutine() async {
        busyAction = "delete"
        defer { busyAction = nil }
        do {
            let result = try await appState.gatewayClient.deleteRoutine(id: routine.id)
            actionMessage = "已提交：\(result.status)"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func jsonBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(ICColor.textSecondary)
            .textSelection(.enabled)
    }
}

private struct MissionDetailView: View {
    @Environment(AppState.self) private var appState
    let mission: MissionSummary

    @State private var detail: MissionDetailResponse?
    @State private var actionMessage: String?
    @State private var errorMessage: String?
    @State private var busyAction: String?

    var body: some View {
        List {
            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("概览") {
                LabeledContent("名称", value: detail?.name ?? mission.name)
                LabeledContent("状态", value: ActivityHomeView.localizedStatusTitle(detail?.status ?? mission.status ?? "unknown"))
                if let cadenceDescription = detail?.cadenceDescription ?? mission.cadenceDescription, !cadenceDescription.isEmpty {
                    LabeledContent("节奏", value: cadenceDescription)
                }
                if let createdAt = detail?.createdAt ?? mission.createdAt, !createdAt.isEmpty {
                    LabeledContent("创建时间", value: createdAt)
                }
                if let updatedAt = detail?.updatedAt ?? mission.updatedAt, !updatedAt.isEmpty {
                    LabeledContent("更新时间", value: updatedAt)
                }
                if let nextFireAt = detail?.nextFireAt, !nextFireAt.isEmpty {
                    LabeledContent("下次触发", value: nextFireAt)
                }
                if let currentFocus = detail?.currentFocus ?? mission.currentFocus, !currentFocus.isEmpty {
                    LabeledContent("当前焦点", value: currentFocus)
                }
            }

            Section("目标") {
                Text(detail?.goal ?? mission.goal ?? "未提供使命目标。")
                    .foregroundStyle(ICColor.textPrimary)
            }

            Section("操作") {
                Button(busyAction == "fire" ? "处理中…" : "立即推进") {
                    Task { await fireMission() }
                }
                .disabled(busyAction != nil)

                Button(busyAction == "pause" ? "处理中…" : "暂停使命") {
                    Task { await pauseMission() }
                }
                .disabled(busyAction != nil)

                Button(busyAction == "resume" ? "处理中…" : "恢复使命") {
                    Task { await resumeMission() }
                }
                .disabled(busyAction != nil)
            }

            if let detail {
                Section("方法与预算") {
                    if !detail.approachHistory.isEmpty {
                        ForEach(Array(detail.approachHistory.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text("方案 \(index + 1)")
                                    .font(.subheadline.weight(.medium))
                                Text(item)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    LabeledContent("今日线程", value: "\(detail.threadsToday)")
                    LabeledContent("每日上限", value: "\(detail.maxThreadsPerDay)")
                    if let successCriteria = detail.successCriteria, !successCriteria.isEmpty {
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text("成功标准")
                                .font(.subheadline.weight(.medium))
                            Text(successCriteria)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !detail.notifyChannels.isEmpty {
                    Section("通知渠道") {
                        ForEach(detail.notifyChannels, id: \.self) { channel in
                            Text(channel)
                        }
                    }
                }

                Section("节奏配置") {
                    Text(detail.cadence.prettyText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ICColor.textSecondary)
                        .textSelection(.enabled)
                }

                if !detail.threads.isEmpty {
                    Section("关联线程") {
                        ForEach(detail.threads) { thread in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(thread.goal)
                                    .font(.subheadline.weight(.medium))
                                Text(thread.id)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(ICColor.textSecondary)
                                Text("\(thread.threadType) · \(thread.state) · Steps \(thread.stepCount)")
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("标识") {
                Text(mission.id)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle(detail?.name ?? mission.name)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        errorMessage = nil

        if appState.gatewayConfiguration.isDemoMode {
            return
        }

        do {
            detail = try await appState.gatewayClient.missionDetail(id: mission.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fireMission() async {
        busyAction = "fire"
        defer { busyAction = nil }
        do {
            let result = try await appState.gatewayClient.fireMission(id: mission.id)
            actionMessage = result.fired ? "使命已推进。" : "使命没有启动新的线程。"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pauseMission() async {
        busyAction = "pause"
        defer { busyAction = nil }
        do {
            _ = try await appState.gatewayClient.pauseMission(id: mission.id)
            actionMessage = "使命已暂停。"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resumeMission() async {
        busyAction = "resume"
        defer { busyAction = nil }
        do {
            _ = try await appState.gatewayClient.resumeMission(id: mission.id)
            actionMessage = "使命已恢复。"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
