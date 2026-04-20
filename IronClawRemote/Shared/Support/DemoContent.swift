import Foundation

enum DemoContent {
    static let demoHost = "demo.ironclaw.local"
    static let gatewayConfiguration = GatewayConfiguration(
        name: "IronClaw Demo",
        baseURL: URL(string: "https://\(demoHost)")!,
        token: ""
    )

    static let profile = GatewayProfile(
        id: "demo-operator",
        displayName: "Demo Operator",
        email: "demo@ironclaw.local",
        role: "Preview Mode"
    )

    static let assistantThreadID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let operationsThreadID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let approvalThreadID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static let assistantThread = ThreadInfo(
        id: assistantThreadID,
        state: "active",
        turnCount: 3,
        createdAt: "2026-04-20 08:40",
        updatedAt: "2026-04-20 09:12",
        title: "IronClaw Assistant",
        threadType: "assistant",
        channel: "ops"
    )

    static let threads: [ThreadInfo] = [
        ThreadInfo(
            id: operationsThreadID,
            state: "ready",
            turnCount: 2,
            createdAt: "2026-04-20 08:55",
            updatedAt: "2026-04-20 09:15",
            title: "Morning Ops Review",
            threadType: "conversation",
            channel: "deploy"
        ),
        ThreadInfo(
            id: approvalThreadID,
            state: "waiting",
            turnCount: 1,
            createdAt: "2026-04-20 09:03",
            updatedAt: "2026-04-20 09:18",
            title: "Approval Flow Demo",
            threadType: "conversation",
            channel: "production"
        )
    ]

    static let histories: [UUID: [TurnInfo]] = [
        operationsThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "Give me the morning gateway summary.",
                response: "All core services are healthy. Jobs are draining normally, one deploy routine is queued, and no production incidents are open.",
                state: "completed",
                startedAt: "2026-04-20 08:58",
                completedAt: "2026-04-20 08:58",
                toolCalls: [
                    ToolCallInfo(
                        name: "jobs.snapshot",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "3 running jobs, 1 queued routine, 0 failed missions.",
                        error: nil,
                        rationale: nil
                    )
                ],
                generatedImages: [],
                narrative: "A compact operational snapshot pulled from the demo gateway."
            ),
            TurnInfo(
                turnNumber: 2,
                userInput: "Generate a visual status card for the deploy queue.",
                response: "I prepared a compact queue card so you can preview how generated media appears in the native chat timeline.",
                state: "completed",
                startedAt: "2026-04-20 09:11",
                completedAt: "2026-04-20 09:12",
                toolCalls: [
                    ToolCallInfo(
                        name: "image.render",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "Rendered a lightweight status card preview.",
                        error: nil,
                        rationale: nil
                    )
                ],
                generatedImages: [
                    GeneratedImageInfo(
                        eventID: "demo-image-status-card",
                        dataURL: demoImageDataURL,
                        path: nil
                    )
                ],
                narrative: "This turn demonstrates image results embedded directly inside chat history."
            )
        ],
        approvalThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "Prepare a production restart plan for the API workers.",
                response: "I drafted the restart plan. Approval is required before the simulated run can continue.",
                state: "completed",
                startedAt: "2026-04-20 09:04",
                completedAt: "2026-04-20 09:05",
                toolCalls: [
                    ToolCallInfo(
                        name: "deploy.plan",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "Prepared rolling restart plan for 3 worker pools.",
                        error: nil,
                        rationale: nil
                    )
                ],
                generatedImages: [],
                narrative: "Use this thread to preview the approval card and gate resolution flow."
            )
        ],
        assistantThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "What can this app do in demo mode?",
                response: "You can browse sample threads, stream a fake response, inspect generated image results, preview workspace files, and open activity drill-down screens without a live gateway.",
                state: "completed",
                startedAt: "2026-04-20 08:45",
                completedAt: "2026-04-20 08:45",
                toolCalls: [],
                generatedImages: [],
                narrative: nil
            )
        ]
    ]

    static let pendingGates: [UUID: PendingGateInfo] = [
        approvalThreadID: PendingGateInfo(
            requestID: "demo-gate-approval-1",
            threadID: approvalThreadID.uuidString,
            gateName: "approval",
            toolName: "deploy.restart",
            description: "Approve a simulated rolling restart for the production API worker pools.",
            parameters: "cluster=prod-api, strategy=rolling, max_unavailable=1",
            resumeKind: .string("continue")
        )
    ]

    static let memoryEntries: [MemoryTreeEntry] = [
        MemoryTreeEntry(path: "playbooks", isDir: true),
        MemoryTreeEntry(path: "snapshots", isDir: true),
        MemoryTreeEntry(path: "playbooks/restart-api.md", isDir: false),
        MemoryTreeEntry(path: "playbooks/deploy-checklist.md", isDir: false),
        MemoryTreeEntry(path: "snapshots/morning-brief.md", isDir: false)
    ]

    static let memoryFiles: [String: MemoryReadResponse] = [
        "playbooks/restart-api.md": MemoryReadResponse(
            path: "playbooks/restart-api.md",
            content: "# Restart API Workers\n\n1. Drain queue depth below 20.\n2. Restart one worker pool at a time.\n3. Verify /healthz and queue lag after each pool.\n4. Watch jobs dashboard for 10 minutes.",
            updatedAt: "2026-04-20 08:30"
        ),
        "playbooks/deploy-checklist.md": MemoryReadResponse(
            path: "playbooks/deploy-checklist.md",
            content: "# Deploy Checklist\n\n- Validate gateway connectivity\n- Confirm no pending approvals\n- Snapshot active jobs\n- Notify operators in #deploy-room\n- Start routine and monitor first 5 minutes",
            updatedAt: "2026-04-20 08:52"
        ),
        "snapshots/morning-brief.md": MemoryReadResponse(
            path: "snapshots/morning-brief.md",
            content: "# Morning Brief\n\n- Gateway: healthy\n- Jobs running: 3\n- Routines queued: 1\n- Missions blocked: 0\n- Next release window: 10:30 local time",
            updatedAt: "2026-04-20 09:10"
        )
    ]

    static let jobs: [JobSummary] = [
        JobSummary(id: "job-demo-sync", title: "Workspace sync", source: "gateway.sync", status: "running", createdAt: "2026-04-20 09:02"),
        JobSummary(id: "job-demo-render", title: "Status card render", source: "image.render", status: "completed", createdAt: "2026-04-20 09:12"),
        JobSummary(id: "job-demo-refresh", title: "Routine refresh", source: "activity.refresh", status: "queued", createdAt: "2026-04-20 09:14")
    ]

    static let routines: [RoutineSummary] = [
        RoutineSummary(id: "routine-demo-deploy", name: "Deploy queue watcher", trigger: "Every 5 minutes", status: "active"),
        RoutineSummary(id: "routine-demo-memory", name: "Memory digest", trigger: "Weekdays 09:00", status: "ready")
    ]

    static let missions: [MissionSummary] = [
        MissionSummary(id: "mission-demo-polish", name: "Native app polish", goal: "Close parity gaps between the iOS client and the web control surface.", status: "active"),
        MissionSummary(id: "mission-demo-demo", name: "Offline preview", goal: "Keep a no-backend demo path available for design review and CI screenshots.", status: "ready")
    ]

    static func searchResults(for query: String) -> [MemoryListEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        return memoryEntries.compactMap { entry in
            guard entry.path.lowercased().contains(normalized) else { return nil }
            let name = entry.path.split(separator: "/").last.map(String.init) ?? entry.path
            let updatedAt = memoryFiles[entry.path]?.updatedAt
            return MemoryListEntry(name: name, path: entry.path, isDir: entry.isDir, updatedAt: updatedAt)
        }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func reply(for message: String, attachmentCount: Int) -> String {
        let normalized = message.lowercased()

        if normalized.contains("deploy") {
            return "The demo deploy queue is stable. One routine is queued, current job throughput is healthy, and there are no blocked missions."
        }

        if normalized.contains("memory") || normalized.contains("workspace") {
            return "The demo workspace contains playbooks, snapshots, and search results so you can preview file browsing without connecting to a gateway."
        }

        if normalized.contains("image") || normalized.contains("visual") || normalized.contains("render") {
            return "I generated a lightweight preview response so you can inspect how streamed text and generated images appear together in the native timeline."
        }

        if attachmentCount > 0 {
            return "I received \(attachmentCount) image\(attachmentCount == 1 ? "" : "s") in demo mode. This preview simulates a multimodal reply without sending data to a real gateway."
        }

        return "Demo mode is active. Connect a live IronClaw gateway in Settings when you want real threads, workspace files, and operational activity."
    }

    static func shouldRequireApproval(for message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("restart") || normalized.contains("approve") || normalized.contains("production")
    }

    static func streamingChunks(for text: String) -> [String] {
        let words = text.split(separator: " ")
        guard !words.isEmpty else { return [text] }

        var chunks: [String] = []
        var index = 0
        while index < words.count {
            let upperBound = min(index + 4, words.count)
            let chunk = words[index..<upperBound].joined(separator: " ")
            chunks.append(chunk + (upperBound < words.count ? " " : ""))
            index = upperBound
        }
        return chunks
    }

    static func generatedImages(for message: String) -> [GeneratedImageInfo] {
        let normalized = message.lowercased()
        guard normalized.contains("image") || normalized.contains("visual") || normalized.contains("render") else {
            return []
        }

        return [
            GeneratedImageInfo(
                eventID: UUID().uuidString,
                dataURL: demoImageDataURL,
                path: nil
            )
        ]
    }

    static var demoImageDataURL: String {
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlH0mUAAAAASUVORK5CYII="
    }
}
