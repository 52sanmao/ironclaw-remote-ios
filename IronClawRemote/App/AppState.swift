import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var gatewayConfiguration = GatewayConfiguration.sample
    var session = SessionState()
    var selectedTab: AppTab = .dashboard
    var preferredTheme: ThemePreference = .system
    var pendingConsoleRoute: ConsoleRoute?

    var preferredColorScheme: ColorScheme? {
        switch preferredTheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var gatewayClient: GatewayClient {
        GatewayClient(configuration: gatewayConfiguration)
    }

    func refreshProfile() async {
        session.connectionStatus = .connecting
        session.lastErrorMessage = nil

        if gatewayConfiguration.isDemoMode {
            session.profile = DemoContent.profile
            session.isAuthenticated = true
            session.connectionStatus = .connected
            return
        }

        do {
            let profile = try await gatewayClient.profile()
            session.profile = profile
            session.isAuthenticated = true
            session.connectionStatus = .connected
        } catch {
            session.profile = nil
            session.isAuthenticated = false
            session.connectionStatus = .degraded
            session.lastErrorMessage = error.localizedDescription
        }
    }

    func openConsole(_ route: ConsoleRoute) {
        pendingConsoleRoute = route
        selectedTab = .console
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case chat
    case console

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "工作台"
        case .chat: "对话"
        case .console: "控制台"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.3.group.bubble.left"
        case .chat: "message.badge.waveform"
        case .console: "slider.horizontal.3"
        }
    }
}

enum ConsoleRoute: String, Hashable, Identifiable {
    case workspace
    case activity
    case extensions
    case skills
    case tokens
    case gatewayStatus
    case settings
    case profile
    case logs
    case adminUsers
    case adminUsage
    case adminSecrets
    case pairing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspace: "工作区"
        case .activity: "运行中心"
        case .extensions: "扩展"
        case .skills: "技能"
        case .tokens: "令牌"
        case .gatewayStatus: "网关状态"
        case .settings: "设置"
        case .profile: "个人资料"
        case .logs: "日志"
        case .adminUsers: "用户管理"
        case .adminUsage: "用量总览"
        case .adminSecrets: "Secrets"
        case .pairing: "配对审批"
        }
    }

    var systemImage: String {
        switch self {
        case .workspace: "folder"
        case .activity: "waveform.path.ecg"
        case .extensions: "puzzlepiece.extension"
        case .skills: "wand.and.stars"
        case .tokens: "key.fill"
        case .gatewayStatus: "antenna.radiowaves.left.and.right"
        case .settings: "gearshape"
        case .profile: "person.crop.circle"
        case .logs: "doc.text.magnifyingglass"
        case .adminUsers: "person.3.fill"
        case .adminUsage: "chart.bar.doc.horizontal"
        case .adminSecrets: "lock.shield"
        case .pairing: "link.circle"
        }
    }
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}
