import SwiftUI

struct ConsolePreferencesView: View {
    @Environment(AppState.self) private var appState
    @State private var errorMessage: String?
    @Binding var showingConnectionSheet: Bool

    var body: some View {
        Form {
            Section("连接") {
                LabeledContent("名称", value: appState.gatewayConfiguration.name)
                LabeledContent("基础地址", value: appState.gatewayConfiguration.baseURL.absoluteString)
                Button("编辑连接") {
                    showingConnectionSheet = true
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

            Section("远端设置") {
                NavigationLink("查看全部设置项") {
                    SettingsListView()
                }
            }
        }
        .navigationTitle("设置")
    }
}

