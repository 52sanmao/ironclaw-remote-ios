import SwiftUI

struct ExtensionsView: View {
    @Environment(AppState.self) private var appState
    @State private var extensions: [ConsoleExtension] = []
    @State private var tools: [ConsoleToolInfo] = []
    @State private var isLoading = false
    @State private var busyExtensionName: String?
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        List {
            Section {
                NavigationLink("扩展注册表") {
                    ExtensionsRegistryView()
                }
            }

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

            Section("已安装扩展") {
                if isLoading && extensions.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if extensions.isEmpty {
                    Text("当前没有已安装扩展。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(extensions) { item in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(item.displayName ?? item.name)
                                        .font(.headline)
                                    Text(item.kind)
                                        .font(.caption)
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                                Spacer()
                                ConsoleBadge(text: extensionStatusText(item), color: extensionStatusColor(item))
                            }

                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if !item.tools.isEmpty {
                                Text("工具：\(item.tools.prefix(4).joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if let error = item.activationError, !error.isEmpty {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.danger)
                            }

                            HStack {
                                Button(item.active ? "已激活" : "激活") {
                                    Task { await activateExtension(item) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(item.active || busyExtensionName == item.name)

                                if let activationStatus = item.activationStatus,
                                   ["configured", "pairing", "failed"].contains(activationStatus) || !item.active {
                                    NavigationLink("配置") {
                                        ExtensionSetupView(extensionName: item.name)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Button("移除", role: .destructive) {
                                    Task { await removeExtension(item) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(busyExtensionName == item.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("当前已注册工具") {
                if isLoading && tools.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if tools.isEmpty {
                    Text("当前没有可展示的工具。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(tools.prefix(20)) { tool in
                        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                            Text(tool.name)
                                .font(.subheadline.weight(.medium))
                            Text(tool.description)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("扩展")
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
            extensions = []
            tools = []
            return
        }

        do {
            async let extensionsRequest = appState.gatewayClient.extensions()
            async let toolsRequest = appState.gatewayClient.extensionTools()
            let fetchedExtensions = try await extensionsRequest
            let fetchedTools = try await toolsRequest
            extensions = fetchedExtensions.sorted {
                ($0.displayName ?? $0.name).localizedStandardCompare($1.displayName ?? $1.name) == .orderedAscending
            }
            tools = fetchedTools.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            extensions = []
            tools = []
            errorMessage = error.localizedDescription
        }
    }

    private func activateExtension(_ item: ConsoleExtension) async {
        busyExtensionName = item.name
        defer { busyExtensionName = nil }
        do {
            let response = try await appState.gatewayClient.activateExtension(name: item.name)
            actionMessage = response.message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeExtension(_ item: ConsoleExtension) async {
        busyExtensionName = item.name
        defer { busyExtensionName = nil }
        do {
            let response = try await appState.gatewayClient.removeExtension(name: item.name)
            actionMessage = response.message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func extensionStatusText(_ item: ConsoleExtension) -> String {
        if let activationStatus = item.activationStatus, !activationStatus.isEmpty {
            switch activationStatus {
            case "active": return "已激活"
            case "configured": return "已配置"
            case "pairing": return "待配对"
            case "failed": return "失败"
            default: return activationStatus
            }
        }
        return item.active ? "已激活" : "未激活"
    }

    private func extensionStatusColor(_ item: ConsoleExtension) -> Color {
        if item.activationError != nil {
            return ICColor.danger
        }
        if item.active {
            return ICColor.success
        }
        if item.authenticated {
            return ICColor.warning
        }
        return ICColor.textSecondary
    }
}

