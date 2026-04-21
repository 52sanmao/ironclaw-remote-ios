import SwiftUI

struct AdminUsersView: View {
    @Environment(AppState.self) private var appState
    @State private var users: [AdminConsoleUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && users.isEmpty {
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

            Section("用户列表") {
                if users.isEmpty {
                    Text("当前没有可展示的用户。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(users) { user in
                        NavigationLink {
                            AdminUserDetailView(user: user)
                        } label: {
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack(alignment: .top, spacing: ICSpacing.sm) {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    if let email = user.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(ICColor.textSecondary)
                                    }
                                }
                                Spacer()
                                ConsoleBadge(text: user.role, color: user.role.lowercased() == "admin" ? ICColor.accent : ICColor.textSecondary)
                            }

                            HStack {
                                Text(user.status)
                                Text("任务 \(user.jobCount)")
                                Text("成本 \(user.totalCost)")
                            }
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)

                            if let lastActiveAt = user.lastActiveAt {
                                Text("最近活跃 \(lastActiveAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("用户管理")
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
            users = []
            return
        }

        do {
            let fetchedUsers = try await appState.gatewayClient.adminUsers()
            users = fetchedUsers.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        } catch {
            users = []
            errorMessage = error.localizedDescription
        }
    }
}

