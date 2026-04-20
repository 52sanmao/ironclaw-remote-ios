import Foundation

struct JobListResponse: Codable {
    let jobs: [JobSummary]

    private enum CodingKeys: String, CodingKey {
        case jobs
    }

    init(jobs: [JobSummary]) {
        self.jobs = jobs
    }

    init(from decoder: Decoder) throws {
        if let jobs = try? [JobSummary](from: decoder) {
            self.jobs = jobs
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.jobs = try container.decode([JobSummary].self, forKey: .jobs)
    }
}

struct RoutineListResponse: Codable {
    let routines: [RoutineSummary]

    private enum CodingKeys: String, CodingKey {
        case routines
    }

    init(routines: [RoutineSummary]) {
        self.routines = routines
    }

    init(from decoder: Decoder) throws {
        if let routines = try? [RoutineSummary](from: decoder) {
            self.routines = routines
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.routines = try container.decode([RoutineSummary].self, forKey: .routines)
    }
}

struct MissionListResponse: Codable {
    let missions: [MissionSummary]

    private enum CodingKeys: String, CodingKey {
        case missions
    }

    init(missions: [MissionSummary]) {
        self.missions = missions
    }

    init(from decoder: Decoder) throws {
        if let missions = try? [MissionSummary](from: decoder) {
            self.missions = missions
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.missions = try container.decode([MissionSummary].self, forKey: .missions)
    }
}

struct JobSummary: Codable, Identifiable {
    let id: String
    let title: String?
    let source: String?
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case source
        case status
        case state
        case createdAt = "created_at"
        case jobKind = "job_kind"
        case userID = "user_id"
    }

    init(id: String, title: String?, source: String?, status: String, createdAt: String?) {
        self.id = id
        self.title = title
        self.source = source
        self.status = status
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        source = try container.decodeIfPresent(String.self, forKey: .source)
            ?? container.decodeIfPresent(String.self, forKey: .jobKind)
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decode(String.self, forKey: .state)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct RoutineSummary: Codable, Identifiable {
    let id: String
    let name: String
    let trigger: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case trigger
        case triggerSummary = "trigger_summary"
        case status
    }

    init(id: String, name: String, trigger: String?, status: String?) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        trigger = try container.decodeIfPresent(String.self, forKey: .trigger)
            ?? container.decodeIfPresent(String.self, forKey: .triggerSummary)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}

struct MissionSummary: Codable, Identifiable {
    let id: String
    let name: String
    let goal: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case goal
        case description
        case status
        case state
    }

    init(id: String, name: String, goal: String?, status: String?) {
        self.id = id
        self.name = name
        self.goal = goal
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? id
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
            ?? container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
    }
}
