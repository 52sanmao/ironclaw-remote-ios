import Foundation

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

    func readMemory(path: String) async throws -> MemoryReadResponse {
        try await request(path: "/api/memory/read", queryItems: [
            URLQueryItem(name: "path", value: path)
        ])
    }

    func searchMemory(query: String) async throws -> [MemoryListEntry] {
        let payload = ["query": query]
        return try await request(path: "/api/memory/search", method: "POST", body: payload)
    }

    func jobs() async throws -> [JobSummary] {
        try await request(path: "/api/jobs")
    }

    func routines() async throws -> [RoutineSummary] {
        try await request(path: "/api/routines")
    }

    func missions() async throws -> [MissionSummary] {
        try await request(path: "/api/missions")
    }

    private func request<Response: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> Response {
        try await request(path: path, queryItems: queryItems, method: "GET", body: Optional<EmptyPayload>.none)
    }

    private func request<Response: Decodable, Body: Encodable>(path: String, queryItems: [URLQueryItem] = [], method: String, body: Body?) async throws -> Response {
        guard !configuration.token.isEmpty else {
            throw GatewayError.missingToken
        }
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
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
