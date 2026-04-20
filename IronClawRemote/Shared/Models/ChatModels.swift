import Foundation

struct ThreadListResponse: Codable {
    let assistantThread: ThreadInfo?
    let threads: [ThreadInfo]
    let activeThread: UUID?

    enum CodingKeys: String, CodingKey {
        case assistantThread = "assistant_thread"
        case threads
        case activeThread = "active_thread"
    }
}

struct ThreadInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let state: String
    let turnCount: Int
    let createdAt: String
    let updatedAt: String
    let title: String?
    let threadType: String?
    let channel: String?

    enum CodingKeys: String, CodingKey {
        case id, state, title, channel
        case turnCount = "turn_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case threadType = "thread_type"
    }
}

struct HistoryResponse: Codable {
    let threadID: UUID
    let turns: [TurnInfo]
    let hasMore: Bool
    let oldestTimestamp: String?
    let pendingGate: PendingGateInfo?

    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case turns
        case hasMore = "has_more"
        case oldestTimestamp = "oldest_timestamp"
        case pendingGate = "pending_gate"
    }
}

struct TurnInfo: Codable, Identifiable {
    var id: Int { turnNumber }
    let turnNumber: Int
    let userInput: String
    let response: String?
    let state: String
    let startedAt: String
    let completedAt: String?
    let toolCalls: [ToolCallInfo]
    let generatedImages: [GeneratedImageInfo]
    let narrative: String?

    enum CodingKeys: String, CodingKey {
        case turnNumber = "turn_number"
        case userInput = "user_input"
        case response, state, narrative
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case toolCalls = "tool_calls"
        case generatedImages = "generated_images"
    }
}

struct ToolCallInfo: Codable, Identifiable {
    var id: String {
        [name, resultPreview, error, rationale].compactMap { $0 }.joined(separator: "|")
    }
    let name: String
    let hasResult: Bool
    let hasError: Bool
    let resultPreview: String?
    let error: String?
    let rationale: String?

    init(name: String, hasResult: Bool, hasError: Bool, resultPreview: String?, error: String?, rationale: String?) {
        self.name = name
        self.hasResult = hasResult
        self.hasError = hasError
        self.resultPreview = resultPreview
        self.error = error
        self.rationale = rationale
    }

    enum CodingKeys: String, CodingKey {
        case name
        case hasResult = "has_result"
        case hasError = "has_error"
        case resultPreview = "result_preview"
        case error, rationale
    }
}

struct GeneratedImageInfo: Codable, Identifiable {
    let eventID: String
    let dataURL: String?
    let path: String?

    var id: String { eventID }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case dataURL = "data_url"
        case path
    }
}

struct PendingGateInfo: Codable, Identifiable {
    let requestID: String
    let threadID: String
    let gateName: String
    let toolName: String
    let description: String
    let parameters: String
    let resumeKind: JSONValue

    var id: String { requestID }

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case threadID = "thread_id"
        case gateName = "gate_name"
        case toolName = "tool_name"
        case description, parameters
        case resumeKind = "resume_kind"
    }
}

struct SendMessageRequest: Codable {
    let content: String
    let threadID: String?
    let timezone: String?
    let images: [ImagePayload]

    enum CodingKeys: String, CodingKey {
        case content
        case threadID = "thread_id"
        case timezone
        case images
    }
}

struct ImagePayload: Codable, Identifiable {
    let id = UUID()
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case data
    }
}

struct SendMessageResponse: Codable {
    let messageID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case status
    }
}
