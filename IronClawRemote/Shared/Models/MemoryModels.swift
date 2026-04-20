import Foundation

struct MemoryTreeResponse: Codable {
    let entries: [MemoryTreeEntry]
}

struct MemoryTreeEntry: Codable, Identifiable, Hashable {
    var id: String { path }
    let path: String
    let isDir: Bool

    enum CodingKeys: String, CodingKey {
        case path
        case isDir = "is_dir"
    }
}

struct MemoryListResponse: Codable {
    let path: String
    let entries: [MemoryListEntry]
}

struct MemoryListEntry: Codable, Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, path
        case isDir = "is_dir"
        case updatedAt = "updated_at"
    }
}

struct MemoryReadResponse: Codable {
    let path: String
    let content: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case path, content
        case updatedAt = "updated_at"
    }
}
