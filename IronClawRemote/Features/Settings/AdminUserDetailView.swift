import SwiftUI

struct AdminUserDetailView: View {
    let user: AdminConsoleUser

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showEditSheet = false
    @State private var editDisplayName = ""
    @State private var editEmail = ""
    @State private var editRole = ""
    @State private var showDeleteConfirm = false

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

            Section("基本信息") {
                LabeledContent("ID", value: user.id)
                LabeledContent("显示名称", value: user.displayName)
                if let email = user.email, !email.isEmpty {
                    LabeledContent("邮箱", value: email)
                }
                LabeledContent("角色", value: user.role)
                LabeledContent("状态", value: user.status)
            }

            Section("元信息") {
                LabeledContent("创建时间", value: user.createdAt)
                LabeledContent("更新时间", value: user.updatedAt)
                if let lastLogin = user.lastLoginAt, !lastLogin.isEmpty {
                    LabeledContent("最近登录", value: lastLogin)
                }
            }

            Section("操作") {
                Button("编辑资料") {
                    editDisplayName = user.displayName
                    editEmail = user.email ?? ""
                    editRole = user.role
                    showEditSheet = true
                }

                if user.status.lowercased() == "active" {
                    Button("挂起用户") {
                        Task { await suspendUser() }
                    }
                    .foregroundStyle(ICColor.warning)
                } else {
                    Button("激活用户") {
                        Task { await activateUser() }
                    }
                    .foregroundStyle(ICColor.success)
                }

                NavigationLink("管理 Secrets") {
                    AdminSecretsView(preselectedUserID: user.id)
                }

                Button("删除用户", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(user.displayName)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("资料") {
                        TextField("显示名称", text: $editDisplayName)
                        TextField("邮箱", text: $editEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        TextField("角色", text: $editRole)
                            .textInputAutocapitalization(.never)
                    }
                }
                .navigationTitle("编辑用户")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showEditSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await saveEdit() }
                        }
                        .disabled(editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                Task { await deleteUser() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作不可撤销，将删除用户 \(user.displayName) 及其所有数据。")
        }
    }

    private func suspendUser() async {
        do {
            let response = try await appState.gatewayClient.suspendAdminUser(id: user.id)
            actionMessage = response.status
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func activateUser() async {
        do {
            let response = try await appState.gatewayClient.activateAdminUser(id: user.id)
            actionMessage = response.status
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveEdit() async {
        let name = editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let email = editEmail.isEmpty ? nil : editEmail
            let role = editRole.isEmpty ? nil : editRole
            let response = try await appState.gatewayClient.updateAdminUser(
                id: user.id,
                displayName: name,
                email: email,
                role: role
            )
            actionMessage = "已更新"
            showEditSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteUser() async {
        do {
            let response = try await appState.gatewayClient.deleteAdminUser(id: user.id)
            if response.deleted {
                actionMessage = "已删除"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
