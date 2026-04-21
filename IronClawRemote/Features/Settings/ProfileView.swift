import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var profile: GatewayProfile?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var editDisplayName = ""
    @State private var showEditSheet = false

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

            if let profile {
                Section("基本信息") {
                    LabeledContent("显示名称", value: profile.displayName)
                    if let email = profile.email, !email.isEmpty {
                        LabeledContent("邮箱", value: email)
                    }
                    if let role = profile.role, !role.isEmpty {
                        LabeledContent("角色", value: role)
                    }
                    if let status = profile.status, !status.isEmpty {
                        LabeledContent("状态", value: status)
                    }
                }

                Section("元信息") {
                    if let createdAt = profile.createdAt, !createdAt.isEmpty {
                        LabeledContent("创建时间", value: createdAt)
                    }
                    if let lastLoginAt = profile.lastLoginAt, !lastLoginAt.isEmpty {
                        LabeledContent("最近登录", value: lastLoginAt)
                    }
                }

                Section {
                    Button("编辑显示名称") {
                        editDisplayName = profile.displayName
                        showEditSheet = true
                    }
                }
            } else if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    Text("暂无资料")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }
        }
        .navigationTitle("个人资料")
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("显示名称") {
                        TextField("名称", text: $editDisplayName)
                            .textInputAutocapitalization(.never)
                    }
                }
                .navigationTitle("编辑资料")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await saveDisplayName() }
                        }
                        .disabled(editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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
            profile = GatewayProfile(displayName: "演示用户", role: "admin", status: "active")
            return
        }

        do {
            profile = try await appState.gatewayClient.profile()
            if let p = profile {
                appState.session.profile = p
            }
        } catch {
            profile = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveDisplayName() async {
        let name = editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let response = try await appState.gatewayClient.updateProfile(displayName: name)
            actionMessage = "已更新为 \(response.displayName)"
            showEditSheet = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
