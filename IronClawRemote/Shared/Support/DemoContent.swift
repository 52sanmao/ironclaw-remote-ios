import Foundation

enum DemoContent {
    static let demoHost = "demo.ironclaw.local"
    static let gatewayConfiguration = GatewayConfiguration(
        name: "Rare Lark 网关",
        baseURL: URL(string: "https://rare-lark.agent4.near.ai")!,
        token: "b5af51dc17344eab80981e47f5ab5784a0f1df4846e7229fba421ae97021aa1e"
    )

    static let profile = GatewayProfile(
        id: "demo-operator",
        displayName: "演示操作员",
        email: "demo@ironclaw.local",
        role: "预览模式"
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
        title: "IronClaw 助手",
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
            title: "晨间运维巡检",
            threadType: "conversation",
            channel: "deploy"
        ),
        ThreadInfo(
            id: approvalThreadID,
            state: "waiting",
            turnCount: 1,
            createdAt: "2026-04-20 09:03",
            updatedAt: "2026-04-20 09:18",
            title: "审批流演示",
            threadType: "conversation",
            channel: "production"
        )
    ]

    static let histories: [UUID: [TurnInfo]] = [
        operationsThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "给我一份今天早上的网关摘要。",
                response: "所有核心服务都很健康。任务正在正常排空，当前有一个部署例程排队中，生产环境没有未关闭事件。",
                state: "completed",
                startedAt: "2026-04-20 08:58",
                completedAt: "2026-04-20 08:58",
                toolCalls: [
                    ToolCallInfo(
                        name: "jobs.snapshot",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "3 个运行中任务，1 个排队例程，0 个失败使命。",
                        error: nil,
                        rationale: nil
                    )
                ],
                generatedImages: [],
                narrative: "这是从演示网关提取的一份精简运行摘要。"
            ),
            TurnInfo(
                turnNumber: 2,
                userInput: "为部署队列生成一张可视化状态卡片。",
                response: "我准备了一张精简的队列卡片，方便你预览原生聊天时间线里生成媒体的显示效果。",
                state: "completed",
                startedAt: "2026-04-20 09:11",
                completedAt: "2026-04-20 09:12",
                toolCalls: [
                    ToolCallInfo(
                        name: "image.render",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "已渲染轻量状态卡片预览。",
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
                narrative: "这一轮用于演示聊天记录里直接嵌入图像结果的效果。"
            )
        ],
        approvalThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "为 API worker 准备一份生产重启计划。",
                response: "我已经起草了重启计划。继续这个模拟运行前需要审批。",
                state: "completed",
                startedAt: "2026-04-20 09:04",
                completedAt: "2026-04-20 09:05",
                toolCalls: [
                    ToolCallInfo(
                        name: "deploy.plan",
                        hasResult: true,
                        hasError: false,
                        resultPreview: "已为 3 组 worker 池准备滚动重启计划。",
                        error: nil,
                        rationale: nil
                    )
                ],
                generatedImages: [],
                narrative: "这个会话用于预览审批卡片和审批处理流程。"
            )
        ],
        assistantThreadID: [
            TurnInfo(
                turnNumber: 1,
                userInput: "这个应用在演示模式下能做什么？",
                response: "你可以浏览示例会话、查看模拟流式回复、检查生成图像结果、预览工作区文件，并在没有真实网关的情况下打开活动详情界面。",
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
            description: "请审批这个模拟的生产 API worker 池滚动重启。",
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
            content: "# 重启 API Workers\n\n1. 将队列深度排空到 20 以下。\n2. 每次只重启一组 worker 池。\n3. 每组完成后检查 /healthz 和队列延迟。\n4. 持续观察任务面板 10 分钟。",
            updatedAt: "2026-04-20 08:30"
        ),
        "playbooks/deploy-checklist.md": MemoryReadResponse(
            path: "playbooks/deploy-checklist.md",
            content: "# 部署清单\n\n- 验证网关连接\n- 确认没有待审批项\n- 快照当前活动任务\n- 在 #deploy-room 通知操作员\n- 启动例程并观察前 5 分钟",
            updatedAt: "2026-04-20 08:52"
        ),
        "snapshots/morning-brief.md": MemoryReadResponse(
            path: "snapshots/morning-brief.md",
            content: "# 晨间简报\n\n- 网关：健康\n- 运行中任务：3\n- 排队例程：1\n- 阻塞使命：0\n- 下一个发布时间窗口：本地时间 10:30",
            updatedAt: "2026-04-20 09:10"
        )
    ]

    static let jobs: [JobSummary] = [
        JobSummary(id: "job-demo-sync", title: "工作区同步", source: "gateway.sync", status: "running", createdAt: "2026-04-20 09:02"),
        JobSummary(id: "job-demo-render", title: "状态卡片渲染", source: "image.render", status: "completed", createdAt: "2026-04-20 09:12"),
        JobSummary(id: "job-demo-refresh", title: "例程刷新", source: "activity.refresh", status: "queued", createdAt: "2026-04-20 09:14")
    ]

    static let routines: [RoutineSummary] = [
        RoutineSummary(id: "routine-demo-deploy", name: "部署队列观察", trigger: "每 5 分钟", status: "active"),
        RoutineSummary(id: "routine-demo-memory", name: "记忆摘要", trigger: "工作日 09:00", status: "ready")
    ]

    static let missions: [MissionSummary] = [
        MissionSummary(id: "mission-demo-polish", name: "原生应用打磨", goal: "缩小 iOS 客户端与 Web 控制面的能力差距。", status: "active"),
        MissionSummary(id: "mission-demo-demo", name: "离线预览", goal: "为设计评审和 CI 截图保留一个无需后端的演示路径。", status: "ready")
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
            return "演示部署队列状态稳定。当前有一个例程排队，任务吞吐健康，没有被阻塞的使命。"
        }

        if normalized.contains("memory") || normalized.contains("workspace") {
            return "演示工作区包含操作手册、快照和搜索结果，因此你无需连接网关也能预览文件浏览体验。"
        }

        if normalized.contains("image") || normalized.contains("visual") || normalized.contains("render") {
            return "我生成了一条轻量预览回复，方便你检查原生时间线里流式文本与生成图像的组合显示效果。"
        }

        if attachmentCount > 0 {
            return "我在演示模式下收到了 \(attachmentCount) 张图片。这个预览会模拟多模态回复，但不会把数据发送到真实网关。"
        }

        return "当前为演示模式。需要真实会话、工作区文件和运行活动时，请在设置中连接正式 IronClaw 网关。"
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
