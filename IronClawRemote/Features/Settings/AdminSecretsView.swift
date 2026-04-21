import SwiftUI

struct AdminSecretsView: View {
    var preselectedUserID: String? = nil
    @Environment(AppState.self) private var appState
    @State private var users: [AdminConsoleUser] = []
    @State private var selectedUser: AdminConsoleUser?
    @State private var secrets: [AdminUserSecretRef] = []
    @State private var isLoadingUsers = false
    @State private var isLoadingSecrets = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showAddSheet = false
    @State private var newSecretName = ""
    @State private var newSecretValue = ""
    @State private var newSecretProvider = ""

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

            Section("选择用户") {
                if isLoadingUsers && users.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if users.isEmpty {
                    Text("没有可展示的用户")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    Picker("用户", selection: Binding(
                        get: { selectedUser?.id ?? "" },
                        set: { newID in
                            if let user = users.first(where: { $0.id == newID }) {
                                selectedUser = user
                                Task { await loadSecrets(for: user.id) }
                            }
                        }
                    )) {
                        Text("请选择").tag("")
                        ForEach(users) { user in
                            Text("\(user.displayName) (\(user.email ?? user.id))").tag(user.id)
                        }
                    }
                }
            }

            if let user = selectedUser {
                Section("\(user.displayName) 的 Secrets") {
                    if isLoadingSecrets {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if secrets.isEmpty {
                        Text("该用户没有 Secrets")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    } else {
                        ForEach(secrets) { secret in
                            HStack {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(secret.name)
                                        .font(.subheadline.weight(.medium))
                                    if let provider = secret.provider, !provider.isEmpty {
                                        Text(provider)
                                            .font(.caption2)
                                            .foregroundStyle(ICColor.textSecondary)
                                    }
                                }
                                Spacer()
                                Button("删除", role: .destructive) {
                                    Task { await deleteSecret(name: secret.name, userID: user.id) }
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button("新增 Secret") {
                        newSecretName = ""
                        newSecretValue = ""
                        newSecretProvider = ""
                        showAddSheet = true
                    }
                }
            }
        }
        .navigationTitle("Secrets 管理")
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                Form {
                    Section("Secret 信息") {
                        TextField("名称", text: $newSecretName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("值", text: $newSecretValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Provider（可选）", text: $newSecretProvider)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("新增 Secret")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await addSecret() }
                        }
                        .disabled(newSecretName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newSecretValue.isEmpty)
                    }
                }
            }
        }
        .task {
            await loadUsers()
        }
        .refreshable {
            await loadUsers()
            if let user = selectedUser {
                await loadSecrets(for: user.id)
            }
        }
    }

    private func loadUsers() async {
        isLoadingUsers = true
        errorMessage = nil
        defer { isLoadingUsers = false }

        if appState.gatewayConfiguration.isDemoMode {
            users = []
            return
        }

        do {
            let fetched = try await appState.gatewayClient.adminUsers()
            users = fetched.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        } catch {
            users = []
            errorMessage = error.localizedDescription
        }
    }

    private func loadSecrets(for userID: String) async {
        isLoadingSecrets = true
        errorMessage = nil
        defer { isLoadingSecrets = false }

        if appState.gatewayConfiguration.isDemoMode {
            secrets = []
            return
        }

        do {
            secrets = try await appState.gatewayClient.adminUserSecrets(userID: userID)
        } catch {
            secrets = []
            errorMessage = error.localizedDescription
        }
    }

    private func addSecret() async {
        guard let user = selectedUser else { return }
        let name = newSecretName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !newSecretValue.isEmpty else { return }

        do {
            let provider = newSecretProvider.isEmpty ? nil : newSecretProvider
            let response = try await appState.gatewayClient.putAdminUserSecret(
                userID: user.id,
                name: name,
                value: newSecretValue,
                provider: provider
            )
            actionMessage = response.status
            showAddSheet = false
            await loadSecrets(for: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSecret(name: String, userID: String) async {
        do {
            let response = try await appState.gatewayClient.deleteAdminUserSecret(userID: userID, name: name)
            if response.deleted {
                actionMessage = "已删除 \(name)"
            }
            await loadSecrets(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
