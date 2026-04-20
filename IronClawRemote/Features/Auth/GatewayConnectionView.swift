import SwiftUI

struct GatewayConnectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseURL = ""
    @State private var token = ""
    @State private var isTesting = false
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("网关") {
                    TextField("显示名称", text: $name)
                    TextField("基础地址", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("令牌", text: $token)
                }

                Section {
                    Button("保存连接") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(isTesting ? "测试中…" : "测试连接") {
                        Task { await testConnection() }
                    }
                    .disabled(isTesting)
                }

                if let validationMessage {
                    Section("状态") {
                        Text(validationMessage)
                            .foregroundStyle(ICColor.danger)
                    }
                } else if let error = appState.session.lastErrorMessage {
                    Section("状态") {
                        Text(error)
                            .foregroundStyle(ICColor.danger)
                    }
                } else if let profile = appState.session.profile {
                    Section("已连接") {
                        LabeledContent("名称", value: profile.displayName)
                        if let email = profile.email {
                            LabeledContent("邮箱", value: email)
                        }
                    }
                }
            }
            .navigationTitle("连接")
            .onAppear {
                name = appState.gatewayConfiguration.name
                baseURL = appState.gatewayConfiguration.baseURL.absoluteString
                token = appState.gatewayConfiguration.token
            }
        }
    }

    private func save() {
        guard let configuration = validatedConfiguration() else { return }
        validationMessage = nil
        appState.gatewayConfiguration = configuration
        dismiss()
    }

    private func testConnection() async {
        guard let configuration = validatedConfiguration() else { return }
        validationMessage = nil
        isTesting = true
        appState.gatewayConfiguration = configuration
        await appState.refreshProfile()
        isTesting = false
    }

    private func validatedConfiguration() -> GatewayConfiguration? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseURL.isEmpty else {
            validationMessage = "请输入网关地址。"
            return nil
        }

        guard let normalized = GatewayConfiguration.normalizeGatewayInput(trimmedBaseURL) else {
            validationMessage = "请输入有效的 http 或 https 网关地址。"
            return nil
        }

        let resolvedToken = trimmedToken.isEmpty ? (normalized.token ?? "") : trimmedToken

        if resolvedToken.isEmpty, GatewayConfiguration.isDemoURL(normalized.url) {
            return GatewayConfiguration(
                name: trimmedName.isEmpty ? "IronClaw 演示" : trimmedName,
                baseURL: normalized.url,
                token: ""
            )
        }

        guard !resolvedToken.isEmpty else {
            validationMessage = "请输入网关令牌。"
            return nil
        }

        return GatewayConfiguration(
            name: trimmedName.isEmpty ? "IronClaw 网关" : trimmedName,
            baseURL: normalized.url,
            token: resolvedToken
        )
    }
}
