import Foundation

enum ConsoleActionError: LocalizedError {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        }
    }
}

struct ExtensionListResponseDTO: Decodable {
    let extensions: [ConsoleExtension]
}

struct ConsoleExtension: Decodable, Identifiable {
    let name: String
    let displayName: String?
    let kind: String
    let description: String?
    let url: String?
    let authenticated: Bool
    let active: Bool
    let tools: [String]
    let needsSetup: Bool
    let hasAuth: Bool
    let activationStatus: String?
    let activationError: String?
    let version: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case kind
        case description
        case url
        case authenticated
        case active
        case tools
        case needsSetup = "needs_setup"
        case hasAuth = "has_auth"
        case activationStatus = "activation_status"
        case activationError = "activation_error"
        case version
    }
}

struct ToolListResponseDTO: Decodable {
    let tools: [ConsoleToolInfo]
}

struct ConsoleToolInfo: Decodable, Identifiable {
    let name: String
    let description: String

    var id: String { name }
}

struct GatewayActionResponse: Decodable {
    let success: Bool
    let message: String
    let authURL: String?
    let awaitingToken: Bool?
    let instructions: String?
    let activated: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case authURL = "auth_url"
        case awaitingToken = "awaiting_token"
        case instructions
        case activated
    }
}

struct SkillListResponseDTO: Decodable {
    let skills: [ConsoleSkill]
    let count: Int
}

struct ConsoleSkill: Decodable, Identifiable {
    let name: String
    let description: String
    let version: String
    let trust: String
    let source: String
    let keywords: [String]

    var id: String { name }
}

struct SkillSearchResponseDTO: Decodable {
    let catalog: [SkillCatalogEntry]
    let installed: [ConsoleSkill]
    let registryURL: String
    let catalogError: String?

    enum CodingKeys: String, CodingKey {
        case catalog
        case installed
        case registryURL = "registry_url"
        case catalogError = "catalog_error"
    }
}

struct SkillCatalogEntry: Decodable, Identifiable {
    let slug: String
    let name: String
    let description: String
    let version: String?
    let score: Double?
    let updatedAt: String?
    let stars: Int?
    let downloads: Int?
    let owner: String?
    let installed: Bool

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case name
        case description
        case version
        case score
        case updatedAt
        case stars
        case downloads
        case owner
        case installed
    }
}

struct APITokenListResponseDTO: Decodable {
    let tokens: [APITokenRecord]
}

struct APITokenRecord: Decodable, Identifiable {
    let id: String
    let name: String
    let tokenPrefix: String
    let expiresAt: String?
    let lastUsedAt: String?
    let createdAt: String
    let revokedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case revokedAt = "revoked_at"
    }
}

struct APITokenCreateResult: Decodable {
    let token: String
    let id: String
    let name: String
    let tokenPrefix: String
    let expiresAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case token
        case id
        case name
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct TokenRevokeResult: Decodable {
    let status: String
    let id: String
}

struct GatewayStatusInfo: Decodable {
    let version: String
    let sseConnections: Int
    let wsConnections: Int
    let totalConnections: Int
    let uptimeSecs: Int
    let restartEnabled: Bool
    let dailyCost: String?
    let actionsThisHour: Int?
    let modelUsage: [GatewayModelUsageEntry]?
    let llmBackend: String
    let llmModel: String
    let enabledChannels: [String]

    enum CodingKeys: String, CodingKey {
        case version
        case sseConnections = "sse_connections"
        case wsConnections = "ws_connections"
        case totalConnections = "total_connections"
        case uptimeSecs = "uptime_secs"
        case restartEnabled = "restart_enabled"
        case dailyCost = "daily_cost"
        case actionsThisHour = "actions_this_hour"
        case modelUsage = "model_usage"
        case llmBackend = "llm_backend"
        case llmModel = "llm_model"
        case enabledChannels = "enabled_channels"
    }
}

struct GatewayModelUsageEntry: Decodable, Identifiable {
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cost: String

    var id: String { model }

    enum CodingKeys: String, CodingKey {
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cost
    }
}

struct SettingsListResponseDTO: Decodable {
    let settings: [RemoteSetting]
}

struct RemoteSetting: Decodable, Identifiable {
    let key: String
    let value: JSONValue
    let updatedAt: String

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case updatedAt = "updated_at"
    }
}

struct AdminUserListResponseDTO: Decodable {
    let users: [AdminConsoleUser]
}

struct AdminConsoleUser: Decodable, Identifiable {
    let id: String
    let email: String?
    let displayName: String
    let status: String
    let role: String
    let createdAt: String
    let updatedAt: String
    let lastLoginAt: String?
    let createdBy: String?
    let jobCount: Int
    let totalCost: String
    let lastActiveAt: String?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case status
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLoginAt = "last_login_at"
        case createdBy = "created_by"
        case jobCount = "job_count"
        case totalCost = "total_cost"
        case lastActiveAt = "last_active_at"
        case metadata
    }
}

struct AdminUsageStats: Decodable {
    let period: String
    let since: String
    let usage: [AdminUsageEntry]
}

struct AdminUsageEntry: Decodable, Identifiable {
    let userID: String
    let model: String
    let callCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalCost: String

    var id: String { "\(userID)-\(model)" }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case model
        case callCount = "call_count"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalCost = "total_cost"
    }
}

struct AdminUsageSummary: Decodable {
    let users: AdminUsageUsers
    let jobs: AdminUsageJobs
    let usage30d: AdminUsageWindow
    let uptimeSeconds: Int

    enum CodingKeys: String, CodingKey {
        case users
        case jobs
        case usage30d = "usage_30d"
        case uptimeSeconds = "uptime_seconds"
    }
}

struct AdminUsageUsers: Decodable {
    let total: Int
    let active: Int
    let suspended: Int
    let admins: Int
}

struct AdminUsageJobs: Decodable {
    let total: Int
}

struct AdminUsageWindow: Decodable {
    let llmCalls: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalCost: String

    enum CodingKeys: String, CodingKey {
        case llmCalls = "llm_calls"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalCost = "total_cost"
    }
}

extension JSONValue {
    var compactText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .array(let values):
            let text = values.prefix(3).map(\.compactText).joined(separator: ", ")
            return values.count > 3 ? "[\(text), …]" : "[\(text)]"
        case .object(let object):
            let keys = object.keys.sorted()
            let text = keys.prefix(3).map { key in
                "\(key): \(object[key]?.compactText ?? "null")"
            }.joined(separator: ", ")
            return object.count > 3 ? "{\(text), …}" : "{\(text)}"
        case .null:
            return "null"
        }
    }

    var prettyText: String {
        switch self {
        case .string(let value):
            return value
        case .number, .bool, .array, .object, .null:
            guard let data = try? JSONEncoder().encode(self),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: pretty, encoding: .utf8) else {
                return compactText
            }
            return text
        }
    }
}
