import Foundation

struct JobSummary: Codable, Identifiable {
    let id: String
    let title: String?
    let source: String?
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, source, status
        case createdAt = "created_at"
    }
}

struct RoutineSummary: Codable, Identifiable {
    let id: String
    let name: String
    let trigger: String?
    let status: String?
}

struct MissionSummary: Codable, Identifiable {
    let id: String
    let name: String
    let goal: String?
    let status: String?
}
