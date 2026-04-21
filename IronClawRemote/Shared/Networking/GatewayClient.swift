import Foundation

struct SkillSearchRequestDTO: Encodable {
    let query: String
}

struct SkillInstallRequestDTO: Encodable {
    let name: String
    let slug: String?
    let url: String?
    let content: String?
}

struct CreateTokenRequestDTO: Encodable {
    let name: String
    let expiresInDays: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case expiresInDays = "expires_in_days"
    }
}

struct MemoryWriteRequestDTO: Encodable {
    let path: String
    let content: String
    let layer: String?
    let append: Bool
    let force: Bool
}

struct JobPromptRequestDTO: Encodable {
    let content: String
    let done: Bool
}

struct RoutineToggleRequestDTO: Encodable {
    let enabled: Bool
}

struct InstallExtensionRequestDTO: Encodable {
    let name: String
    let url: String?
    let kind: String?
}

struct ExtensionSetupSubmitRequestDTO: Encodable {
    let secrets: [String: String]
    let fields: [String: String]
}

struct UpdateProfileRequestDTO: Encodable {
    let displayName: String?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case metadata
    }
}

struct SettingWriteRequestDTO: Encodable {
    let value: JSONValue
}

struct SettingsImportRequestDTO: Encodable {
    let settings: [String: JSONValue]
}

struct UpdateLogLevelRequestDTO: Encodable {
    let level: String
}

struct AdminUserCreateRequestDTO: Encodable {
    let displayName: String
    let email: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case role
    }
}

struct AdminUserUpdateRequestDTO: Encodable {
    let displayName: String?
    let email: String?
    let role: String?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case role
        case metadata
    }
}

struct AdminUserSecretWriteRequestDTO: Encodable {
    let value: String
    let provider: String?
    let expiresInDays: Int?

    enum CodingKeys: String, CodingKey {
        case value
        case provider
        case expiresInDays = "expires_in_days"
    }
}

struct PairingApproveRequestDTO: Encodable {
    let code: String
}

enum GatewayError: LocalizedError {
    case invalidResponse
    case invalidURL
    case httpError(Int, String)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "网关返回了无效响应。"
        case .invalidURL:
            return "网关地址无效。"
        case .httpError(let code, let message):
            return "网关错误 \(code)：\(message)"
        case .missingToken:
            return "需要提供网关令牌。"
        }
    }
}

struct GatewayClient {
    var configuration: GatewayConfiguration
    var session: URLSession = .shared

    func profile() async throws -> GatewayProfile {
        try await request(path: "/api/profile")
    }

    func updateProfile(displayName: String? = nil, metadata: JSONValue? = nil) async throws -> GatewayProfileUpdateResponse {
        try await request(path: "/api/profile", method: "PATCH", body: UpdateProfileRequestDTO(displayName: displayName, metadata: metadata))
    }

    func threads() async throws -> ThreadListResponse {
        try await request(path: "/api/chat/threads")
    }

    func createThread() async throws -> ThreadInfo {
        try await request(path: "/api/chat/thread/new", method: "POST", body: EmptyPayload())
    }

    func history(threadID: UUID) async throws -> HistoryResponse {
        try await request(path: "/api/chat/history", queryItems: [
            URLQueryItem(name: "thread_id", value: threadID.uuidString)
        ])
    }

    func sendMessage(_ payload: SendMessageRequest) async throws -> SendMessageResponse {
        try await request(path: "/api/chat/send", method: "POST", body: payload)
    }

    func resolveGate(requestID: String, threadID: String?, resolution: GateResolutionPayloadDTO) async throws {
        let payload = GateResolveRequestDTO(requestID: requestID, threadID: threadID, resolution: resolution)
        let _: EmptyResponse = try await request(path: "/api/chat/gate/resolve", method: "POST", body: payload)
    }

    func memoryTree() async throws -> MemoryTreeResponse {
        try await request(path: "/api/memory/tree")
    }

    func memoryList(path: String = "") async throws -> MemoryListResponse {
        try await request(path: "/api/memory/list", queryItems: path.isEmpty ? [] : [
            URLQueryItem(name: "path", value: path)
        ])
    }

    func readMemory(path: String) async throws -> MemoryReadResponse {
        try await request(path: "/api/memory/read", queryItems: [
            URLQueryItem(name: "path", value: path)
        ])
    }

    func writeMemory(path: String, content: String, layer: String? = nil, append: Bool = false, force: Bool = false) async throws {
        let payload = MemoryWriteRequestDTO(path: path, content: content, layer: layer, append: append, force: force)
        let _: EmptyResponse = try await request(path: "/api/memory/write", method: "POST", body: payload)
    }

    func searchMemory(query: String) async throws -> [MemoryListEntry] {
        let payload = ["query": query]
        let response: MemorySearchResponse = try await request(path: "/api/memory/search", method: "POST", body: payload)
        return response.results.map(\.listEntry)
    }

    func jobs() async throws -> [JobSummary] {
        let response: JobListResponse = try await request(path: "/api/jobs")
        return response.jobs
    }

    func jobsSummary() async throws -> JobSummaryMetrics {
        try await request(path: "/api/jobs/summary")
    }

    func jobDetail(id: String) async throws -> JobDetailResponse {
        try await request(path: "/api/jobs/\(id)")
    }

    func cancelJob(id: String) async throws -> GatewayOperationStatus {
        try await request(path: "/api/jobs/\(id)/cancel", method: "POST", body: EmptyPayload())
    }

    func restartJob(id: String) async throws -> GatewayOperationStatus {
        try await request(path: "/api/jobs/\(id)/restart", method: "POST", body: EmptyPayload())
    }

    func promptJob(id: String, content: String, done: Bool = false) async throws -> GatewayOperationStatus {
        try await request(path: "/api/jobs/\(id)/prompt", method: "POST", body: JobPromptRequestDTO(content: content, done: done))
    }

    func jobEvents(id: String) async throws -> JobEventListResponse {
        try await request(path: "/api/jobs/\(id)/events")
    }

    func jobFiles(id: String, path: String = "") async throws -> ProjectFilesResponse {
        try await request(path: "/api/jobs/\(id)/files/list", queryItems: path.isEmpty ? [] : [
            URLQueryItem(name: "path", value: path)
        ])
    }

    func readJobFile(id: String, path: String) async throws -> ProjectFileReadResponse {
        try await request(path: "/api/jobs/\(id)/files/read", queryItems: [
            URLQueryItem(name: "path", value: path)
        ])
    }

    func routines() async throws -> [RoutineSummary] {
        let response: RoutineListResponse = try await request(path: "/api/routines")
        return response.routines
    }

    func routinesSummary() async throws -> RoutineSummaryMetrics {
        try await request(path: "/api/routines/summary")
    }

    func routineDetail(id: String) async throws -> RoutineDetailResponse {
        try await request(path: "/api/routines/\(id)")
    }

    func triggerRoutine(id: String) async throws -> GatewayOperationStatus {
        try await request(path: "/api/routines/\(id)/trigger", method: "POST", body: EmptyPayload())
    }

    func toggleRoutine(id: String, enabled: Bool) async throws -> GatewayOperationStatus {
        try await request(path: "/api/routines/\(id)/toggle", method: "POST", body: RoutineToggleRequestDTO(enabled: enabled))
    }

    func deleteRoutine(id: String) async throws -> GatewayOperationStatus {
        try await request(path: "/api/routines/\(id)", method: "DELETE", body: Optional<EmptyPayload>.none)
    }

    func routineRuns(id: String) async throws -> RoutineRunsResponse {
        try await request(path: "/api/routines/\(id)/runs")
    }

    func missions() async throws -> [MissionSummary] {
        let response: MissionListResponse = try await request(path: "/api/engine/missions")
        return response.missions
    }

    func missionsSummary() async throws -> MissionSummaryMetrics {
        try await request(path: "/api/engine/missions/summary")
    }

    func missionDetail(id: String) async throws -> MissionDetailResponse {
        let response: MissionDetailEnvelope = try await request(path: "/api/engine/missions/\(id)")
        return response.mission
    }

    func fireMission(id: String) async throws -> MissionFireResponse {
        try await request(path: "/api/engine/missions/\(id)/fire", method: "POST", body: EmptyPayload())
    }

    func pauseMission(id: String) async throws -> EngineActionResponse {
        try await request(path: "/api/engine/missions/\(id)/pause", method: "POST", body: EmptyPayload())
    }

    func resumeMission(id: String) async throws -> EngineActionResponse {
        try await request(path: "/api/engine/missions/\(id)/resume", method: "POST", body: EmptyPayload())
    }

    func extensions() async throws -> [ConsoleExtension] {
        let response: ExtensionListResponseDTO = try await request(path: "/api/extensions")
        return response.extensions
    }

    func extensionTools() async throws -> [ConsoleToolInfo] {
        let response: ToolListResponseDTO = try await request(path: "/api/extensions/tools")
        return response.tools
    }

    func extensionRegistry(query: String? = nil) async throws -> [ExtensionRegistryEntry] {
        let response: ExtensionRegistryResponseDTO = try await request(path: "/api/extensions/registry", queryItems: query?.isEmpty == false ? [
            URLQueryItem(name: "query", value: query)
        ] : [])
        return response.entries
    }

    func installExtension(name: String, url: String? = nil, kind: String? = nil) async throws -> GatewayActionResponse {
        try await request(path: "/api/extensions/install", method: "POST", body: InstallExtensionRequestDTO(name: name, url: url, kind: kind))
    }

    func extensionSetup(name: String) async throws -> ExtensionSetupResponseDTO {
        try await request(path: "/api/extensions/\(name)/setup")
    }

    func submitExtensionSetup(name: String, secrets: [String: String], fields: [String: String]) async throws -> GatewayActionResponse {
        try await request(path: "/api/extensions/\(name)/setup", method: "POST", body: ExtensionSetupSubmitRequestDTO(secrets: secrets, fields: fields))
    }

    func activateExtension(name: String) async throws -> GatewayActionResponse {
        try await request(path: "/api/extensions/\(name)/activate", method: "POST", body: EmptyPayload())
    }

    func removeExtension(name: String) async throws -> GatewayActionResponse {
        try await request(path: "/api/extensions/\(name)/remove", method: "POST", body: EmptyPayload())
    }

    func skills() async throws -> SkillListResponseDTO {
        try await request(path: "/api/skills")
    }

    func searchSkills(query: String) async throws -> SkillSearchResponseDTO {
        try await request(path: "/api/skills/search", method: "POST", body: SkillSearchRequestDTO(query: query))
    }

    func installSkill(name: String, slug: String? = nil) async throws -> GatewayActionResponse {
        try await request(
            path: "/api/skills/install",
            method: "POST",
            headers: ["X-Confirm-Action": "true"],
            body: SkillInstallRequestDTO(name: name, slug: slug, url: nil, content: nil)
        )
    }

    func removeSkill(name: String) async throws -> GatewayActionResponse {
        try await request(path: "/api/skills/\(name)", method: "DELETE", headers: ["X-Confirm-Action": "true"], body: Optional<EmptyPayload>.none)
    }

    func tokens() async throws -> [APITokenRecord] {
        let response: APITokenListResponseDTO = try await request(path: "/api/tokens")
        return response.tokens
    }

    func createToken(name: String, expiresInDays: Int? = nil) async throws -> APITokenCreateResult {
        try await request(path: "/api/tokens", method: "POST", body: CreateTokenRequestDTO(name: name, expiresInDays: expiresInDays))
    }

    func revokeToken(id: String) async throws -> TokenRevokeResult {
        try await request(path: "/api/tokens/\(id)", method: "DELETE", body: Optional<EmptyPayload>.none)
    }

    func gatewayStatus() async throws -> GatewayStatusInfo {
        try await request(path: "/api/gateway/status")
    }

    func logsLevel() async throws -> GatewayLogLevel {
        try await request(path: "/api/logs/level")
    }

    func setLogsLevel(_ level: String) async throws -> GatewayLogLevel {
        try await request(path: "/api/logs/level", method: "PUT", body: UpdateLogLevelRequestDTO(level: level))
    }

    func logEventsStream() throws -> AsyncThrowingStream<GatewayLogEntry, Error> {
        guard !configuration.effectiveToken.isEmpty else {
            throw GatewayError.missingToken
        }
        let token = configuration.effectiveToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? configuration.effectiveToken
        guard let url = URL(string: "/api/logs/events?token=\(token)", relativeTo: configuration.normalizedBaseURL) else {
            throw GatewayError.invalidURL
        }

        let sse = SSEClient(session: session)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await envelope in sse.stream(url: url) {
                        if let event = envelope.event, event != "log" {
                            continue
                        }
                        let data = Data(envelope.data.utf8)
                        guard let entry = try? JSONDecoder.ironClaw.decode(GatewayLogEntry.self, from: data) else {
                            continue
                        }
                        continuation.yield(entry)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func settings() async throws -> [RemoteSetting] {
        let response: SettingsListResponseDTO = try await request(path: "/api/settings")
        return response.settings
    }

    func exportSettings() async throws -> [String: JSONValue] {
        let response: SettingsExportResponseDTO = try await request(path: "/api/settings/export")
        return response.settings
    }

    func importSettings(_ settings: [String: JSONValue]) async throws {
        let _: EmptyResponse = try await request(path: "/api/settings/import", method: "POST", body: SettingsImportRequestDTO(settings: settings))
    }

    func setting(key: String) async throws -> RemoteSetting {
        try await request(path: "/api/settings/\(key)")
    }

    func setSetting(key: String, value: JSONValue) async throws {
        let _: EmptyResponse = try await request(path: "/api/settings/\(key)", method: "PUT", body: SettingWriteRequestDTO(value: value))
    }

    func deleteSetting(key: String) async throws {
        let _: EmptyResponse = try await request(path: "/api/settings/\(key)", method: "DELETE", body: Optional<EmptyPayload>.none)
    }

    func adminUsers() async throws -> [AdminConsoleUser] {
        let response: AdminUserListResponseDTO = try await request(path: "/api/admin/users")
        return response.users
    }

    func adminUserDetail(id: String) async throws -> AdminConsoleUser {
        try await request(path: "/api/admin/users/\(id)")
    }

    func createAdminUser(displayName: String, email: String? = nil, role: String? = nil) async throws -> AdminUserCreateResponseDTO {
        try await request(path: "/api/admin/users", method: "POST", body: AdminUserCreateRequestDTO(displayName: displayName, email: email, role: role))
    }

    func updateAdminUser(id: String, displayName: String? = nil, email: String? = nil, role: String? = nil, metadata: JSONValue? = nil) async throws -> AdminUserProfileResponseDTO {
        try await request(path: "/api/admin/users/\(id)", method: "PATCH", body: AdminUserUpdateRequestDTO(displayName: displayName, email: email, role: role, metadata: metadata))
    }

    func suspendAdminUser(id: String) async throws -> AdminUserStatusResponseDTO {
        try await request(path: "/api/admin/users/\(id)/suspend", method: "POST", body: EmptyPayload())
    }

    func activateAdminUser(id: String) async throws -> AdminUserStatusResponseDTO {
        try await request(path: "/api/admin/users/\(id)/activate", method: "POST", body: EmptyPayload())
    }

    func deleteAdminUser(id: String) async throws -> AdminUserDeleteResponseDTO {
        try await request(path: "/api/admin/users/\(id)", method: "DELETE", body: Optional<EmptyPayload>.none)
    }

    func adminUserSecrets(userID: String) async throws -> [AdminUserSecretRef] {
        let response: AdminUserSecretsResponseDTO = try await request(path: "/api/admin/users/\(userID)/secrets")
        return response.secrets
    }

    func putAdminUserSecret(userID: String, name: String, value: String, provider: String? = nil, expiresInDays: Int? = nil) async throws -> AdminSecretMutationResponseDTO {
        try await request(path: "/api/admin/users/\(userID)/secrets/\(name)", method: "PUT", body: AdminUserSecretWriteRequestDTO(value: value, provider: provider, expiresInDays: expiresInDays))
    }

    func deleteAdminUserSecret(userID: String, name: String) async throws -> AdminSecretDeleteResponseDTO {
        try await request(path: "/api/admin/users/\(userID)/secrets/\(name)", method: "DELETE", body: Optional<EmptyPayload>.none)
    }

    func pairingRequests(channel: String) async throws -> PairingListResponseDTO {
        try await request(path: "/api/pairing/\(channel)")
    }

    func approvePairing(channel: String, code: String) async throws -> GatewayActionResponse {
        try await request(path: "/api/pairing/\(channel)/approve", method: "POST", body: PairingApproveRequestDTO(code: code))
    }

    func adminUsageSummary() async throws -> AdminUsageSummary {
        try await request(path: "/api/admin/usage/summary")
    }

    func adminUsage(period: String = "day") async throws -> AdminUsageStats {
        try await request(path: "/api/admin/usage", queryItems: [
            URLQueryItem(name: "period", value: period)
        ])
    }

    private func request<Response: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> Response {
        try await request(path: path, queryItems: queryItems, method: "GET", headers: [:], body: Optional<EmptyPayload>.none)
    }

    private func request<Response: Decodable, Body: Encodable>(path: String, queryItems: [URLQueryItem] = [], method: String, body: Body?) async throws -> Response {
        try await request(path: path, queryItems: queryItems, method: method, headers: [:], body: body)
    }

    private func request<Response: Decodable, Body: Encodable>(path: String, queryItems: [URLQueryItem] = [], method: String, headers: [String: String], body: Body?) async throws -> Response {
        guard !configuration.effectiveToken.isEmpty else {
            throw GatewayError.missingToken
        }
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.effectiveToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = decodedErrorMessage(from: data)
            throw GatewayError.httpError(httpResponse.statusCode, message)
        }
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try JSONDecoder.ironClaw.decode(Response.self, from: data)
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: configuration.normalizedBaseURL, resolvingAgainstBaseURL: false) else {
            throw GatewayError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let resourcePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, resourcePath].filter { !$0.isEmpty }.joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw GatewayError.invalidURL
        }
        return url
    }

    private func decodedErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
        }

        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text! : "未知错误"
    }
}

private struct EmptyPayload: Encodable {}
private struct EmptyResponse: Decodable {}

private struct MissionDetailEnvelope: Decodable {
    let mission: MissionDetailResponse
}

extension JSONDecoder {
    static var ironClaw: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}

struct GateResolveRequestDTO: Encodable {
    let requestID: String
    let threadID: String?
    let resolution: GateResolutionPayloadDTO

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case threadID = "thread_id"
        case resolution
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestID, forKey: .requestID)
        try container.encodeIfPresent(threadID, forKey: .threadID)
        try resolution.encode(to: encoder)
    }
}

enum GateResolutionPayloadDTO: Encodable {
    case approved(always: Bool)
    case denied
    case credentialProvided(token: String)
    case cancelled

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        switch self {
        case .approved(let always):
            try container.encode("approved", forKey: DynamicCodingKey("resolution"))
            try container.encode(always, forKey: DynamicCodingKey("always"))
        case .denied:
            try container.encode("denied", forKey: DynamicCodingKey("resolution"))
        case .credentialProvided(let token):
            try container.encode("credential_provided", forKey: DynamicCodingKey("resolution"))
            try container.encode(token, forKey: DynamicCodingKey("token"))
        case .cancelled:
            try container.encode("cancelled", forKey: DynamicCodingKey("resolution"))
        }
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init(_ string: String) { self.stringValue = string }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
}
