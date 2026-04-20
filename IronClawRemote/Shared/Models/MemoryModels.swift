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

struct MemorySearchResponse: Codable {
    let results: [MemorySearchHit]

    private enum CodingKeys: String, CodingKey {
        case results
    }

    init(results: [MemorySearchHit]) {
        self.results = results
    }

    init(from decoder: Decoder) throws {
        if let results = try? [MemorySearchHit](from: decoder) {
            self.results = results
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.results = try container.decode([MemorySearchHit].self, forKey: .results)
    }
}

struct MemorySearchHit: Codable, Hashable {
    let path: String
    let content: String
    let score: Double?

    var listEntry: MemoryListEntry {
        MemoryListEntry(
            name: path.split(separator: "/").last.map(String.init) ?? path,
            path: path,
            isDir: false,
            updatedAt: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case path
        case content
        case score
    }

    init(path: String, content: String, score: Double?) {
        self.path = path
        self.content = content
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        content = try container.decode(String.self, forKey: .content)
        if let doubleScore = try container.decodeIfPresent(Double.self, forKey: .score) {
            score = doubleScore
        } else if let intScore = try container.decodeIfPresent(Int.self, forKey: .score) {
            score = Double(intScore)
        } else {
            score = nil
        }
    }
}
