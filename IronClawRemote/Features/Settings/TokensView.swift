import SwiftUI

struct TokensView: View {
    @Environment(AppState.self) private var appState
    @State private var tokens: [APITokenRecord] = []
    @State private var newTokenName = ""
    @State private var createdToken: APITokenCreateResult?
    @State private var isLoading = false
    @State private var actionTarget: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("创建令牌") {
                TextField("令牌名称", text: $newTokenName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("创建") {
                    Task { await createToken() }
                }
                .disabled(newTokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let createdToken {
                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                        Text("新令牌")
                            .font(.subheadline.weight(.medium))
                        Text(createdToken.token)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Text("请立即保存，网关只会展示一次。")
                            .font(.caption2)
                            .foregroundStyle(ICColor.warning)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("现有令牌") {
                if isLoading && tokens.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if tokens.isEmpty {
                    Text("当前没有 API 令牌。")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(tokens) { token in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack {
                                VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                                    Text(token.name)
                                        .font(.headline)
                                    Text(token.tokenPrefix)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(ICColor.textSecondary)
                                }
                                Spacer()
                                if token.revokedAt != nil {
                                    ConsoleBadge(text: "已撤销", color: ICColor.danger)
                                }
                            }

                            Text("创建于 \(token.createdAt)")
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)

                            if let lastUsedAt = token.lastUsedAt {
                                Text("最近使用 \(lastUsedAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if let expiresAt = token.expiresAt {
                                Text("过期时间 \(expiresAt)")
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            if token.revokedAt == nil {
                                Button("撤销", role: .destructive) {
                                    Task { await revokeToken(token) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(actionTarget == token.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("令牌")
        .task {
            await loadTokens()
        }
        .refreshable {
            await loadTokens()
        }
    }

    private func loadTokens() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            tokens = []
            return
        }

        do {
            let fetchedTokens = try await appState.gatewayClient.tokens()
            tokens = fetchedTokens.sorted {
                $0.createdAt.localizedStandardCompare($1.createdAt) == .orderedDescending
            }
        } catch {
            tokens = []
            errorMessage = error.localizedDescription
        }
    }

    private func createToken() async {
        let name = newTokenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            createdToken = try await appState.gatewayClient.createToken(name: name)
            newTokenName = ""
            await loadTokens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokeToken(_ token: APITokenRecord) async {
        actionTarget = token.id
        defer { actionTarget = nil }
        do {
            _ = try await appState.gatewayClient.revokeToken(id: token.id)
            await loadTokens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

