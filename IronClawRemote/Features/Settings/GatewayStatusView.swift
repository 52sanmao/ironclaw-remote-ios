import SwiftUI

struct GatewayStatusView: View {
    @Environment(AppState.self) private var appState
    @State private var status: GatewayStatusInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && status == nil {
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

            if let status {
                Section("网关") {
                    LabeledContent("版本", value: status.version)
                    LabeledContent("运行时长", value: formattedDuration(status.uptimeSecs))
                    LabeledContent("重启支持", value: status.restartEnabled ? "是" : "否")
                    LabeledContent("日成本", value: status.dailyCost ?? "—")
                    LabeledContent("小时动作数", value: status.actionsThisHour.map(String.init) ?? "—")
                }

                Section("连接") {
                    LabeledContent("SSE", value: "\(status.sseConnections)")
                    LabeledContent("WebSocket", value: "\(status.wsConnections)")
                    LabeledContent("总连接", value: "\(status.totalConnections)")
                }

                Section("模型") {
                    LabeledContent("后端", value: status.llmBackend)
                    LabeledContent("模型", value: status.llmModel)
                    if !status.enabledChannels.isEmpty {
                        LabeledContent("已启用通道", value: status.enabledChannels.joined(separator: ", "))
                    }
                }

                if let modelUsage = status.modelUsage, !modelUsage.isEmpty {
                    Section("模型用量") {
                        ForEach(modelUsage) { item in
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(item.model)
                                    .font(.subheadline.weight(.medium))
                                Text("输入 \(item.inputTokens) / 输出 \(item.outputTokens) / 成本 \(item.cost)")
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("网关状态")
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
            status = nil
            return
        }

        do {
            status = try await appState.gatewayClient.gatewayStatus()
        } catch {
            status = nil
            errorMessage = error.localizedDescription
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        if minutes > 0 {
            return "\(minutes)分\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }
}

