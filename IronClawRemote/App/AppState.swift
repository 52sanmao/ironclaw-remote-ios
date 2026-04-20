import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var gatewayConfiguration = GatewayConfiguration.sample
    var session = SessionState()
    var selectedTab: AppTab = .chat
    var preferredTheme: ThemePreference = .system
    var chat = ChatStore()
    var workspace = WorkspaceStore()
    var activity = ActivityStore()

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
}

enum AppTab: String, CaseIterable, Identifiable {
    case chat
    case workspace
    case activity
    case discover
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "聊天"
        case .workspace: "工作区"
        case .activity: "活动"
        case .discover: "发现"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "message.badge.waveform"
        case .workspace: "folder"
        case .activity: "waveform.path.ecg"
        case .discover: "square.grid.2x2"
        case .settings: "gearshape"
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
