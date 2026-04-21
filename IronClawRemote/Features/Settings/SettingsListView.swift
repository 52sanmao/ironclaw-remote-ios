import SwiftUI

struct SettingsListView: View {
    @Environment(AppState.self) private var appState
    @State private var settings: [RemoteSetting] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showImportSheet = false
    @State private var importText = ""

    var body: some View {
        List {
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

            Section {
                HStack {
                    Button("导出全部") {
                        Task { await export() }
                    }
                    .buttonStyle(.bordered)
                    Button("导入") {
                        importText = ""
                        showImportSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section("设置项") {
                if isLoading && settings.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if settings.isEmpty {
                    Text("当前没有远端设置")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(settings) { setting in
                        NavigationLink {
                            SettingDetailView(setting: setting)
                        } label: {
                            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                Text(setting.key)
                                    .font(.subheadline.weight(.medium))
                                Text(setting.value.compactText)
                                    .font(.caption)
                                    .foregroundStyle(ICColor.textSecondary)
                                    .lineLimit(2)
                                Text(setting.updatedAt)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("远端设置")
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                Form {
                    Section("设置快照 JSON") {
                        TextEditor(text: $importText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 200)
                    }
                }
                .navigationTitle("导入设置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showImportSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("导入") {
                            Task { await doImport() }
                        }
                        .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
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
            settings = []
            return
        }

        do {
            let fetched = try await appState.gatewayClient.settings()
            settings = fetched.sorted {
                $0.key.localizedStandardCompare($1.key) == .orderedAscending
            }
        } catch {
            settings = []
            errorMessage = error.localizedDescription
        }
    }

    private func export() async {
        do {
            let exported = try await appState.gatewayClient.exportSettings()
            let raw = exported.mapValues { $0.rawValue }
            let jsonData = try JSONSerialization.data(withJSONObject: raw, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                UIPasteboard.general.string = jsonString
                actionMessage = "已复制到剪贴板"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func doImport() async {
        let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的 JSON"])
            }
            var converted: [String: JSONValue] = [:]
            for (k, v) in json {
                converted[k] = JSONValue(any: v)
            }
            try await appState.gatewayClient.importSettings(converted)
            actionMessage = "导入成功"
            showImportSheet = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SettingDetailView: View {
    let setting: RemoteSetting

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editText = ""
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        List {
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

            Section("键") {
                Text(setting.key)
                    .font(.system(.subheadline, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("当前值") {
                Text(setting.value.compactText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("编辑值 (JSON)") {
                TextEditor(text: $editText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
            }

            Section {
                Button(isSaving ? "保存中…" : "保存") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("删除", role: .destructive) {
                    Task { await delete() }
                }
                .buttonStyle(.bordered)
                .disabled(isDeleting)
            }
        }
        .navigationTitle("设置详情")
        .task {
            editText = setting.value.compactText
        }
    }

    private func save() async {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            guard let data = text.data(using: .utf8) else {
                throw NSError(domain: "Save", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的编码"])
            }
            let json = try JSONSerialization.jsonObject(with: data)
            let value = JSONValue(any: json)
            try await appState.gatewayClient.setSetting(key: setting.key, value: value)
            actionMessage = "已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await appState.gatewayClient.deleteSetting(key: setting.key)
            actionMessage = "已删除"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
