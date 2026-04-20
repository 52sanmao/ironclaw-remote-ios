import Foundation

struct GatewayConfiguration: Codable, Equatable {
    var name: String
    var baseURL: URL
    var token: String

    static let sample = DemoContent.gatewayConfiguration

    var isDemoMode: Bool {
        token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Self.isDemoURL(baseURL)
    }

    static func isDemoURL(_ url: URL) -> Bool {
        url.host?.lowercased() == DemoContent.demoHost
    }
}

struct SessionState: Equatable {
    var profile: GatewayProfile?
    var isAuthenticated = false
    var connectionStatus: ConnectionStatus = .disconnected
    var lastErrorMessage: String?
}

enum ConnectionStatus: String, Equatable {
    case disconnected
    case connecting
    case connected
    case degraded
}

struct GatewayProfile: Codable, Equatable {
    var id: String?
    var displayName: String
    var email: String?
    var role: String?
}
