import SwiftUI

struct AdminUsageView: View {
    @Environment(AppState.self) private var appState
    @State private var summary: AdminUsageSummary?
    @State private var usage: [AdminUsageEntry] = []
    @State private var selectedPeriod = "day"
    @State private var isLoading = false
    @State private var errorMessage: String?


    var body: some View {
        List {
            Section("时间范围") {
                Picker("统计窗口", selection: $selectedPeriod) {
                    Text("日").tag("day")
                    Text("周").tag("week")
                    Text("月").tag("month")
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _, _ in
                    Task { await load() }
                }
            }

            if isLoading && summary == nil && usage.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            if let summary {
                Section("系统总览") {
                    LabeledContent("用户总数", value: "\(summary.users.total)")
                    LabeledContent("活跃用户", value: "\(summary.users.active)")
                    LabeledContent("管理员", value: "\(summary.users.admins)")
                    LabeledContent("已挂起", value: "\(summary.users.suspended)")
                    LabeledContent("任务总数", value: "\(summary.jobs.total)")
                    LabeledContent("近 30 天调用", value: "\(summary.usage30d.llmCalls)")
                    LabeledContent("近 30 天成本", value: summary.usage30d.totalCost)
                    LabeledContent("运行时长", value: "\(summary.uptimeSeconds) 秒")
                }
            }

            Section("模型用量") {
                if usage.isEmpty {
                    Text("当前窗口没有用量数据。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(usage) { item in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(item.userID)
                                .font(.subheadline.weight(.medium))
                            Text(item.model)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                            Text("调用 \(item.callCount) · 输入 \(item.inputTokens) · 输出 \(item.outputTokens) · 成本 \(item.totalCost)")
                                .font(.caption2)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("用量总览")
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
            summary = nil
            usage = []
            return
        }

        do {
            async let summaryRequest = appState.gatewayClient.adminUsageSummary()
            async let usageRequest = appState.gatewayClient.adminUsage(period: selectedPeriod)
            let fetchedSummary = try await summaryRequest
            let fetchedUsage = try await usageRequest
            summary = fetchedSummary
            usage = fetchedUsage.usage.sorted {
                if $0.totalCost == $1.totalCost {
                    return $0.userID.localizedStandardCompare($1.userID) == .orderedAscending
                }
                return $0.totalCost > $1.totalCost
            }
        } catch {
            summary = nil
            usage = []
            errorMessage = error.localizedDescription
        }
    }
}

