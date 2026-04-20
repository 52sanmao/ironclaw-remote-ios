import SwiftUI

struct ActivityHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !hasPrimaryContent {
                    ContentUnavailableView("Loading activity…", systemImage: "bolt.horizontal.circle")
                } else if let errorMessage = viewModel.errorMessage, !hasPrimaryContent {
                    ContentUnavailableView(
                        "Unable to load activity",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: ICSpacing.md) {
                            summarySection
                            if let errorMessage = viewModel.errorMessage {
                                statusNotice(
                                    title: "Refresh failed",
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
            .navigationTitle("Activity")
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
                title: "Jobs",
                value: "\(viewModel.jobs.count)",
                icon: "shippingbox",
                destination: ActivityCollectionView(title: "Jobs") {
                    if viewModel.jobs.isEmpty {
                        emptyCard("No jobs available right now.")
                    } else {
                        ForEach(viewModel.jobs) { job in
                            jobCard(job)
                        }
                    }
                }
            )

            summaryCard(
                title: "Routines",
                value: "\(viewModel.routines.count)",
                icon: "clock.arrow.circlepath",
                destination: ActivityCollectionView(title: "Routines") {
                    if viewModel.routines.isEmpty {
                        emptyCard("No routines available right now.")
                    } else {
                        ForEach(viewModel.routines) { routine in
                            routineCard(routine)
                        }
                    }
                }
            )

            summaryCard(
                title: "Missions",
                value: "\(viewModel.missions.count)",
                icon: "flag.pattern.checkered",
                destination: ActivityCollectionView(title: "Missions") {
                    if let missionsErrorMessage = viewModel.missionsErrorMessage {
                        statusNotice(
                            title: "Missions unavailable",
                            message: missionsErrorMessage,
                            color: ICColor.warning,
                            icon: "flag.slash.fill"
                        )
                    }
                    if viewModel.missions.isEmpty {
                        emptyCard("No missions available from the current gateway.")
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
            "Jobs",
            destination: ActivityCollectionView(title: "Jobs") {
                if viewModel.jobs.isEmpty {
                    emptyCard("No jobs available right now.")
                } else {
                    ForEach(viewModel.jobs) { job in
                        jobCard(job)
                    }
                }
            }
        ) {
            if viewModel.jobs.isEmpty {
                emptyCard("No jobs available right now.")
            } else {
                ForEach(viewModel.jobs.prefix(5)) { job in
                    jobCard(job)
                }
            }
        }
    }

    private var routinesSection: some View {
        section(
            "Routines",
            destination: ActivityCollectionView(title: "Routines") {
                if viewModel.routines.isEmpty {
                    emptyCard("No routines available right now.")
                } else {
                    ForEach(viewModel.routines) { routine in
                        routineCard(routine)
                    }
                }
            }
        ) {
            if viewModel.routines.isEmpty {
                emptyCard("No routines available right now.")
            } else {
                ForEach(viewModel.routines.prefix(5)) { routine in
                    routineCard(routine)
                }
            }
        }
    }

    private var missionsSection: some View {
        section(
            "Missions",
            destination: ActivityCollectionView(title: "Missions") {
                if let missionsErrorMessage = viewModel.missionsErrorMessage {
                    statusNotice(
                        title: "Missions unavailable",
                        message: missionsErrorMessage,
                        color: ICColor.warning,
                        icon: "flag.slash.fill"
                    )
                }
                if viewModel.missions.isEmpty {
                    emptyCard("No missions available from the current gateway.")
                } else {
                    ForEach(viewModel.missions) { mission in
                        missionCard(mission)
                    }
                }
            }
        ) {
            if let missionsErrorMessage = viewModel.missionsErrorMessage {
                statusNotice(
                    title: "Missions unavailable",
                    message: missionsErrorMessage,
                    color: ICColor.warning,
                    icon: "flag.slash.fill"
                )
            }
            if viewModel.missions.isEmpty {
                emptyCard("No missions available from the current gateway.")
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
                Text("Open")
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
                NavigationLink("View All", destination: destination)
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
                    statusBadge(job.status, color: statusColor(for: job.status))
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
                        statusBadge(status, color: statusColor(for: status))
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
                        statusBadge(status, color: statusColor(for: status))
                    }
                }

                Text(mission.goal ?? "No mission goal provided.")
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
        Text(text.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
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
                Section("Overview") {
                    LabeledContent("Title", value: job.title ?? job.id)
                    LabeledContent("Status", value: job.status.capitalized)
                    if let source = job.source, !source.isEmpty {
                        LabeledContent("Source", value: source)
                    }
                    if let createdAt = job.createdAt, !createdAt.isEmpty {
                        LabeledContent("Created", value: createdAt)
                    }
                }

                Section("Identifier") {
                    Text(job.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(job.title ?? "Job")
        }
    }

    private struct RoutineDetailView: View {
        let routine: RoutineSummary

        var body: some View {
            List {
                Section("Overview") {
                    LabeledContent("Name", value: routine.name)
                    if let status = routine.status, !status.isEmpty {
                        LabeledContent("Status", value: status.capitalized)
                    }
                    if let trigger = routine.trigger, !trigger.isEmpty {
                        LabeledContent("Trigger", value: trigger)
                    }
                }

                Section("Identifier") {
                    Text(routine.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(routine.name)
        }
    }

    private struct MissionDetailView: View {
        let mission: MissionSummary

        var body: some View {
            List {
                Section("Overview") {
                    LabeledContent("Name", value: mission.name)
                    if let status = mission.status, !status.isEmpty {
                        LabeledContent("Status", value: status.capitalized)
                    }
                    if let goal = mission.goal, !goal.isEmpty {
                        Text(goal)
                    } else {
                        Text("No mission goal provided.")
                            .foregroundStyle(ICColor.textSecondary)
                    }
                }

                Section("Identifier") {
                    Text(mission.id)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle(mission.name)
        }
    }
}
