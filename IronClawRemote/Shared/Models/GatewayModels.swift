import Foundation

struct GatewayConfiguration: Codable, Equatable {
    var name: String
    var baseURL: URL
    var token: String

    static let sample = DemoContent.gatewayConfiguration

    var effectiveToken: String {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            return trimmedToken
        }
        return Self.tokenQueryValue(from: baseURL) ?? ""
    }

    var normalizedBaseURL: URL {
        Self.normalizeGatewayInput(baseURL.absoluteString)?.url ?? baseURL
    }

    var isDemoMode: Bool {
        effectiveToken.isEmpty && Self.isDemoURL(normalizedBaseURL)
    }

    static func isDemoURL(_ url: URL) -> Bool {
        url.host?.lowercased() == DemoContent.demoHost
    }

    static func normalizeGatewayInput(_ raw: String) -> (url: URL, token: String?)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        var candidates: [String] = []
        if let nested = nestedURLString(in: trimmed) {
            candidates.append(nested)
        }
        candidates.append(trimmed)

        for candidate in candidates {
            guard let parsed = URL(string: candidate),
                  let scheme = parsed.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                continue
            }

            let token = tokenQueryValue(from: parsed)
            guard var components = URLComponents(url: parsed, resolvingAgainstBaseURL: false) else {
                continue
            }
            components.query = nil
            components.fragment = nil
            if let normalized = components.url {
                return (normalized, token)
            }
        }

        return nil
    }

    private static func tokenQueryValue(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.caseInsensitiveCompare("token") == .orderedSame })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nestedURLString(in raw: String) -> String? {
        let lowercased = raw.lowercased()
        guard let firstRange = lowercased.range(of: "https://") ?? lowercased.range(of: "http://") else {
            return nil
        }

        let searchStart = firstRange.upperBound
        let remaining = lowercased[searchStart...]
        guard let secondRange = remaining.range(of: "https://") ?? remaining.range(of: "http://") else {
            return nil
        }

        return String(raw[secondRange.lowerBound...])
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
    var id: String? = nil
    var displayName: String
    var email: String? = nil
    var role: String? = nil
    var status: String? = nil
    var avatarURL: String? = nil
    var createdAt: String? = nil
    var lastLoginAt: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case role
        case status
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }
}

struct GatewayProfileUpdateResponse: Codable, Equatable {
    let id: String
    let displayName: String
    let updated: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case updated
    }
}
