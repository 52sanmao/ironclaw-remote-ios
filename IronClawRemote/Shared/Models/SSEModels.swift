import Foundation

struct ChatEvent: Codable, Identifiable {
    let type: String
    let threadID: String?
    let requestID: String?
    let message: String?
    let content: String?
    let name: String?
    let toolName: String?
    let gateName: String?
    let description: String?
    let parameters: String?
    let preview: String?
    let detail: String?
    let resolution: String?
    let success: Bool?
    let resumeKind: JSONValue?

    var id: String {
        [
            type,
            threadID,
            requestID,
            name,
            toolName,
            gateName,
            content,
            message,
            preview,
            resolution
        ]
        .compactMap { $0 }
        .joined(separator: "-")
    }

    var displayName: String {
        toolName ?? name ?? gateName ?? type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var primaryText: String? {
        content ?? message ?? description ?? preview ?? detail
    }

    enum CodingKeys: String, CodingKey {
        case type, message, content, name, description, parameters, preview, detail, resolution, success
        case threadID = "thread_id"
        case requestID = "request_id"
        case toolName = "tool_name"
        case gateName = "gate_name"
        case resumeKind = "resume_kind"
    }
}
