import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingConnectionSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("网关") {
                    LabeledContent("名称", value: appState.gatewayConfiguration.name)
                    LabeledContent("基础地址", value: appState.gatewayConfiguration.baseURL.absoluteString)
                    if appState.gatewayConfiguration.isDemoMode {
                        Text("当前为演示模式。需要真实后端数据时，可在这里连接正式网关。")
                            .font(.caption)
                            .foregroundStyle(ICColor.textSecondary)
                    }
                    Button("编辑连接") {
                        showingConnectionSheet = true
                    }
                    Button("测试连接") {
                        Task { await appState.refreshProfile() }
                    }
                }

                Section("外观") {
                    Picker("主题", selection: Binding(
                        get: { appState.preferredTheme },
                        set: { appState.preferredTheme = $0 }
                    )) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                }

                Section("资料") {
                    if let profile = appState.session.profile {
                        LabeledContent("名称", value: profile.displayName)
                        if let email = profile.email {
                            LabeledContent("邮箱", value: email)
                        }
                        if let role = profile.role {
                            LabeledContent("角色", value: role)
                        }
                    } else {
                        Text(appState.session.lastErrorMessage ?? "尚未加载资料。")
                            .foregroundStyle(ICColor.textSecondary)
                    }
                }

                Section("关于") {
                    Text("IronClaw Remote 是 IronClaw 网关的原生 iOS 控制端。")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingConnectionSheet) {
                GatewayConnectionView()
            }
        }
    }
}
