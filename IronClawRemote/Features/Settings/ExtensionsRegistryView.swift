import SwiftUI

struct ExtensionsRegistryView: View {
    @Environment(AppState.self) private var appState
    @State private var registryEntries: [ExtensionRegistryEntry] = []
    @State private var searchQuery = ""
    @State private var isLoading = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var busyName: String?

    var body: some View {
        List {
            Section("搜索") {
                TextField("输入关键字", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(isSearching ? "搜索中…" : "搜索注册表") {
                    Task { await search() }
                }
                .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.success)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("可安装扩展") {
                if isLoading && registryEntries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if registryEntries.isEmpty {
                    Text("没有可展示的注册表结果")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(registryEntries) { entry in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(entry.displayName)
                                        .font(.headline)
                                    Text(entry.name)
                                        .font(.caption)
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                                Spacer()
                                if entry.installed {
                                    ConsoleBadge(text: "已安装", color: ICColor.success)
                                }
                            }

                            if !entry.description.isEmpty {
                                Text(entry.description)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                                    .lineLimit(3)
                            }

                            if !entry.keywords.isEmpty {
                                Text(entry.keywords.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if let version = entry.version {
                                Text("版本 \(version)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if !entry.installed {
                                Button("安装") {
                                    Task { await install(entry) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(busyName == entry.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("扩展注册表")
        .task {
            await search()
        }
        .refreshable {
            await search()
        }
    }

    private func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        if appState.gatewayConfiguration.isDemoMode {
            registryEntries = []
            return
        }

        do {
            registryEntries = try await appState.gatewayClient.extensionRegistry(query: query.isEmpty ? nil : query)
        } catch {
            registryEntries = []
            errorMessage = error.localizedDescription
        }
    }

    private func install(_ entry: ExtensionRegistryEntry) async {
        busyName = entry.name
        defer { busyName = nil }
        do {
            let response = try await appState.gatewayClient.installExtension(name: entry.name, url: nil, kind: entry.kind)
            actionMessage = response.message
            await search()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConsoleBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
