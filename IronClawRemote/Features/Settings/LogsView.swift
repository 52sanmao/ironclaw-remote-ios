import SwiftUI

struct LogsView: View {
    @Environment(AppState.self) private var appState
    @State private var entries: [GatewayLogEntry] = []
    @State private var logLevel: GatewayLogLevel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLevelPicker = false
    @State private var selectedLevel = "info"
    @State private var streamTask: Task<Void, Never>?

    private let levelOptions = ["trace", "debug", "info", "warn", "error"]

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section {
                HStack {
                    Text("当前级别")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if let logLevel {
                        Text(logLevel.level)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(levelColor(logLevel.level))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(levelColor(logLevel.level).opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    Button("修改") {
                        selectedLevel = logLevel?.level ?? "info"
                        showLevelPicker = true
                    }
                    .font(.caption)
                }
            }

            Section("日志流") {
                if entries.isEmpty && isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if entries.isEmpty {
                    Text("暂无日志")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            HStack {
                                Text(entry.level.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(levelColor(entry.level))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(levelColor(entry.level).opacity(0.12))
                                    .clipShape(Capsule())
                                Text(entry.target)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                                Spacer()
                                Text(entry.timestamp)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(ICColor.textPrimary)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("日志")
        .confirmationDialog("选择日志级别", isPresented: $showLevelPicker, titleVisibility: .visible) {
            ForEach(levelOptions, id: \.self) { level in
                Button(level.uppercased()) {
                    Task { await setLevel(level) }
                }
            }
            Button("取消", role: .cancel) { }
        }
        .task {
            await loadLevel()
            startStream()
        }
        .onDisappear {
            streamTask?.cancel()
        }
        .refreshable {
            await loadLevel()
            entries.removeAll()
            startStream()
        }
    }

    private func loadLevel() async {
        if appState.gatewayConfiguration.isDemoMode {
            logLevel = GatewayLogLevel(level: "info")
            return
        }
        do {
            logLevel = try await appState.gatewayClient.logsLevel()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setLevel(_ level: String) async {
        do {
            logLevel = try await appState.gatewayClient.setLogsLevel(level)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startStream() {
        streamTask?.cancel()
        streamTask = Task {
            if appState.gatewayConfiguration.isDemoMode {
                isLoading = false
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                let stream = try appState.gatewayClient.logEventsStream()
                for try await entry in stream {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        entries.insert(entry, at: 0)
                        if entries.count > 500 {
                            entries = Array(entries.prefix(500))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error": return ICColor.danger
        case "warn": return ICColor.warning
        case "info": return ICColor.success
        case "debug": return ICColor.accent
        default: return ICColor.textSecondary
        }
    }
}
