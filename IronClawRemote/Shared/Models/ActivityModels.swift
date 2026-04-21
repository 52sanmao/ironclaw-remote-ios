import Foundation

struct JobListResponse: Decodable {
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

struct JobSummaryMetrics: Decodable {
    let total: Int
    let pending: Int
    let inProgress: Int
    let completed: Int
    let failed: Int
    let stuck: Int

    enum CodingKeys: String, CodingKey {
        case total
        case pending
        case inProgress = "in_progress"
        case completed
        case failed
        case stuck
    }
}

struct RoutineListResponse: Decodable {
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

struct RoutineSummaryMetrics: Decodable {
    let total: Int
    let enabled: Int
    let disabled: Int
    let unverified: Int
    let failing: Int
    let runsToday: Int

    enum CodingKeys: String, CodingKey {
        case total
        case enabled
        case disabled
        case unverified
        case failing
        case runsToday = "runs_today"
    }
}

struct MissionListResponse: Decodable {
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

struct MissionSummaryMetrics: Decodable {
    let total: Int
    let active: Int
    let paused: Int
    let completed: Int
    let failed: Int
}

struct JobSummary: Decodable, Identifiable {
    let id: String
    let title: String?
    let source: String?
    let status: String
    let createdAt: String?
    let startedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case source
        case status
        case state
        case createdAt = "created_at"
        case startedAt = "started_at"
        case jobKind = "job_kind"
        case userID = "user_id"
    }

    init(id: String, title: String?, source: String?, status: String, createdAt: String?, startedAt: String? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        source = try container.decodeIfPresent(String.self, forKey: .source)
            ?? container.decodeIfPresent(String.self, forKey: .jobKind)
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
            ?? "unknown"
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
    }
}

struct JobDetailResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let state: String
    let userID: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let elapsedSecs: Int?
    let projectDir: String?
    let browseURL: String?
    let jobMode: String?
    let transitions: [TransitionInfo]
    let canRestart: Bool
    let canPrompt: Bool
    let jobKind: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case state
        case userID = "user_id"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case elapsedSecs = "elapsed_secs"
        case projectDir = "project_dir"
        case browseURL = "browse_url"
        case jobMode = "job_mode"
        case transitions
        case canRestart = "can_restart"
        case canPrompt = "can_prompt"
        case jobKind = "job_kind"
    }
}

struct TransitionInfo: Decodable, Identifiable {
    let from: String
    let to: String
    let timestamp: String
    let reason: String?

    var id: String { "\(timestamp)-\(from)-\(to)" }
}

struct GatewayOperationStatus: Decodable {
    let status: String
    let jobID: String?
    let oldJobID: String?
    let newJobID: String?
    let routineID: String?
    let runID: String?

    enum CodingKeys: String, CodingKey {
        case status
        case jobID = "job_id"
        case oldJobID = "old_job_id"
        case newJobID = "new_job_id"
        case routineID = "routine_id"
        case runID = "run_id"
    }
}

struct JobEventListResponse: Decodable {
    let jobID: String
    let events: [JobEventInfo]

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case events
    }
}

struct JobEventInfo: Decodable, Identifiable {
    let id: String
    let eventType: String
    let data: JSONValue
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case data
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        eventType = try container.decode(String.self, forKey: .eventType)
        data = try container.decode(JSONValue.self, forKey: .data)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

struct ProjectFilesResponse: Decodable {
    let entries: [ProjectFileEntry]
}

struct ProjectFileEntry: Decodable, Identifiable {
    let name: String
    let path: String
    let isDir: Bool

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case isDir = "is_dir"
    }
}

struct ProjectFileReadResponse: Decodable {
    let path: String
    let content: String
}

struct RoutineSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let trigger: String?
    let status: String?
    let enabled: Bool?
    let verificationStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case trigger
        case triggerSummary = "trigger_summary"
        case status
        case enabled
        case verificationStatus = "verification_status"
    }

    init(id: String, name: String, trigger: String?, status: String?) {
        self.id = id
        self.name = name
        self.description = nil
        self.trigger = trigger
        self.status = status
        self.enabled = nil
        self.verificationStatus = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        trigger = try container.decodeIfPresent(String.self, forKey: .trigger)
            ?? container.decodeIfPresent(String.self, forKey: .triggerSummary)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        verificationStatus = try container.decodeIfPresent(String.self, forKey: .verificationStatus)
    }
}

struct RoutineDetailResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
    let enabled: Bool
    let triggerType: String
    let triggerRaw: String
    let triggerSummary: String
    let trigger: JSONValue
    let action: JSONValue
    let guardrails: JSONValue
    let notify: JSONValue
    let lastRunAt: String?
    let nextFireAt: String?
    let runCount: Int
    let consecutiveFailures: Int
    let status: String
    let verificationStatus: String
    let createdAt: String
    let conversationID: String?
    let recentRuns: [RoutineRunInfo]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case enabled
        case triggerType = "trigger_type"
        case triggerRaw = "trigger_raw"
        case triggerSummary = "trigger_summary"
        case trigger
        case action
        case guardrails
        case notify
        case lastRunAt = "last_run_at"
        case nextFireAt = "next_fire_at"
        case runCount = "run_count"
        case consecutiveFailures = "consecutive_failures"
        case status
        case verificationStatus = "verification_status"
        case createdAt = "created_at"
        case conversationID = "conversation_id"
        case recentRuns = "recent_runs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        enabled = try container.decode(Bool.self, forKey: .enabled)
        triggerType = try container.decodeIfPresent(String.self, forKey: .triggerType) ?? ""
        triggerRaw = try container.decodeIfPresent(String.self, forKey: .triggerRaw) ?? ""
        triggerSummary = try container.decodeIfPresent(String.self, forKey: .triggerSummary) ?? ""
        trigger = try container.decode(JSONValue.self, forKey: .trigger)
        action = try container.decode(JSONValue.self, forKey: .action)
        guardrails = try container.decode(JSONValue.self, forKey: .guardrails)
        notify = try container.decode(JSONValue.self, forKey: .notify)
        lastRunAt = try container.decodeIfPresent(String.self, forKey: .lastRunAt)
        nextFireAt = try container.decodeIfPresent(String.self, forKey: .nextFireAt)
        runCount = try Self.decodeInt(container, forKey: .runCount) ?? 0
        consecutiveFailures = try Self.decodeInt(container, forKey: .consecutiveFailures) ?? 0
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        verificationStatus = try container.decodeIfPresent(String.self, forKey: .verificationStatus) ?? "unknown"
        createdAt = try container.decode(String.self, forKey: .createdAt)
        conversationID = try Self.decodeOptionalString(container, forKey: .conversationID)
        recentRuns = try container.decodeIfPresent([RoutineRunInfo].self, forKey: .recentRuns) ?? []
    }
}

struct RoutineRunInfo: Decodable, Identifiable {
    let id: String
    let triggerType: String
    let startedAt: String
    let completedAt: String?
    let status: String
    let resultSummary: String?
    let tokensUsed: Int?
    let jobID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case triggerType = "trigger_type"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case status
        case resultSummary = "result_summary"
        case tokensUsed = "tokens_used"
        case jobID = "job_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        triggerType = try container.decodeIfPresent(String.self, forKey: .triggerType) ?? ""
        startedAt = try container.decode(String.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary)
        tokensUsed = try Self.decodeInt(container, forKey: .tokensUsed)
        jobID = try Self.decodeOptionalString(container, forKey: .jobID)
    }
}

struct RoutineRunsResponse: Decodable {
    let routineID: String
    let runs: [RoutineRunInfo]

    enum CodingKeys: String, CodingKey {
        case routineID = "routine_id"
        case runs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routineID = try Self.decodeString(container, forKey: .routineID)
        runs = try container.decodeIfPresent([RoutineRunInfo].self, forKey: .runs) ?? []
    }
}

struct MissionSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let goal: String?
    let status: String?
    let cadenceType: String?
    let cadenceDescription: String?
    let threadCount: Int?
    let currentFocus: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case goal
        case description
        case status
        case state
        case cadenceType = "cadence_type"
        case cadenceDescription = "cadence_description"
        case threadCount = "thread_count"
        case currentFocus = "current_focus"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String, name: String, goal: String?, status: String?) {
        self.id = id
        self.name = name
        self.goal = goal
        self.status = status
        self.cadenceType = nil
        self.cadenceDescription = nil
        self.threadCount = nil
        self.currentFocus = nil
        self.createdAt = nil
        self.updatedAt = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? id
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
            ?? container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? container.decodeIfPresent(String.self, forKey: .state)
        cadenceType = try container.decodeIfPresent(String.self, forKey: .cadenceType)
        cadenceDescription = try container.decodeIfPresent(String.self, forKey: .cadenceDescription)
        threadCount = try Self.decodeInt(container, forKey: .threadCount)
        currentFocus = try container.decodeIfPresent(String.self, forKey: .currentFocus)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct MissionDetailResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let goal: String
    let status: String
    let cadenceType: String
    let cadenceDescription: String
    let threadCount: Int
    let currentFocus: String?
    let createdAt: String
    let updatedAt: String
    let cadence: JSONValue
    let approachHistory: [String]
    let notifyChannels: [String]
    let successCriteria: String?
    let threadsToday: Int
    let maxThreadsPerDay: Int
    let nextFireAt: String?
    let threads: [EngineThreadInfo]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case goal
        case status
        case cadenceType = "cadence_type"
        case cadenceDescription = "cadence_description"
        case threadCount = "thread_count"
        case currentFocus = "current_focus"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case cadence
        case approachHistory = "approach_history"
        case notifyChannels = "notify_channels"
        case successCriteria = "success_criteria"
        case threadsToday = "threads_today"
        case maxThreadsPerDay = "max_threads_per_day"
        case nextFireAt = "next_fire_at"
        case threads
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        cadenceType = try container.decodeIfPresent(String.self, forKey: .cadenceType) ?? ""
        cadenceDescription = try container.decodeIfPresent(String.self, forKey: .cadenceDescription) ?? ""
        threadCount = try Self.decodeInt(container, forKey: .threadCount) ?? 0
        currentFocus = try container.decodeIfPresent(String.self, forKey: .currentFocus)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        cadence = try container.decode(JSONValue.self, forKey: .cadence)
        approachHistory = try container.decodeIfPresent([String].self, forKey: .approachHistory) ?? []
        notifyChannels = try container.decodeIfPresent([String].self, forKey: .notifyChannels) ?? []
        successCriteria = try container.decodeIfPresent(String.self, forKey: .successCriteria)
        threadsToday = try Self.decodeInt(container, forKey: .threadsToday) ?? 0
        maxThreadsPerDay = try Self.decodeInt(container, forKey: .maxThreadsPerDay) ?? 0
        nextFireAt = try container.decodeIfPresent(String.self, forKey: .nextFireAt)
        threads = try container.decodeIfPresent([EngineThreadInfo].self, forKey: .threads) ?? []
    }
}

struct EngineThreadInfo: Decodable, Identifiable {
    let id: String
    let goal: String
    let threadType: String
    let state: String
    let projectID: String
    let parentID: String?
    let stepCount: Int
    let totalTokens: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case goal
        case threadType = "thread_type"
        case state
        case projectID = "project_id"
        case parentID = "parent_id"
        case stepCount = "step_count"
        case totalTokens = "total_tokens"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeString(container, forKey: .id)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        threadType = try container.decodeIfPresent(String.self, forKey: .threadType) ?? ""
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        projectID = try Self.decodeString(container, forKey: .projectID)
        parentID = try Self.decodeOptionalString(container, forKey: .parentID)
        stepCount = try Self.decodeInt(container, forKey: .stepCount) ?? 0
        totalTokens = try Self.decodeInt(container, forKey: .totalTokens) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

struct MissionFireResponse: Decodable {
    let threadID: String?
    let fired: Bool

    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case fired
    }
}

struct EngineActionResponse: Decodable {
    let ok: Bool
}

private extension Decodable {
    static func decodeString<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) throws -> String {
        if let string = try container.decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try container.decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try container.decodeIfPresent(Double.self, forKey: key) {
            return String(Int(double.rounded()))
        }
        throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing value for \(key.stringValue)"))
    }

    static func decodeOptionalString<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) throws -> String? {
        if let string = try container.decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let int = try container.decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try container.decodeIfPresent(Double.self, forKey: key) {
            return String(Int(double.rounded()))
        }
        return nil
    }

    static func decodeInt<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) throws -> Int? {
        if let int = try container.decodeIfPresent(Int.self, forKey: key) {
            return int
        }
        if let double = try container.decodeIfPresent(Double.self, forKey: key) {
            return Int(double)
        }
        if let string = try container.decodeIfPresent(String.self, forKey: key), let int = Int(string) {
            return int
        }
        return nil
    }
}
