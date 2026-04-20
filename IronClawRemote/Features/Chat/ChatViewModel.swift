import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    var threads: [ThreadInfo] = []
    var assistantThread: ThreadInfo?
    var selectedThread: ThreadInfo?
    var turns: [TurnInfo] = []
    var composerText = ""
    var composerAttachments: [ComposerAttachment] = []
    var composerNotice: ComposerNotice?
    var isLoading = false
    var errorMessage: String?
    var pendingGate: PendingGateInfo?
    var eventFeed: [ChatEvent] = []
    var streamState: ChatStreamState = .idle
    var pendingUserMessage: String?
    var streamingResponseText = ""

    var isStreaming: Bool {
        streamState == .sending || streamState == .streaming
    }

    private var streamTask: Task<Void, Never>?
    private var currentConfiguration: GatewayConfiguration?
    private var isHistoryRefreshScheduled = false
    private var streamConnectionID = UUID()

    func load(using configuration: GatewayConfiguration) async {
        currentConfiguration = configuration
        isLoading = true
        errorMessage = nil
        composerNotice = nil
        defer { isLoading = false }

        if configuration.isDemoMode {
            assistantThread = DemoContent.assistantThread
            threads = DemoContent.threads
            selectedThread = selectedThread ?? DemoContent.assistantThread
            resetLiveState()
            if let selectedThread {
                await loadDemoHistory(threadID: selectedThread.id)
            }
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            let response = try await client.threads()
            assistantThread = response.assistantThread
            threads = response.threads
            selectedThread = selectedThread(from: response)
            resetLiveState()
            if let selectedThread {
                try await loadHistory(threadID: selectedThread.id, using: configuration)
            }
            startStreaming(using: configuration)
        } catch {
            errorMessage = error.localizedDescription
            composerNotice = ComposerNotice(message: "无法从网关加载聊天会话。", tone: .error)
            streamState = .failed
        }
    }

    func selectThread(_ thread: ThreadInfo, configuration: GatewayConfiguration) async {
        currentConfiguration = configuration
        selectedThread = thread
        resetComposerState()
        resetLiveState()
        await refreshHistory(using: configuration)
    }

    func refreshHistory(using configuration: GatewayConfiguration) async {
        currentConfiguration = configuration
        guard let threadID = selectedThread?.id else { return }

        if configuration.isDemoMode {
            await loadDemoHistory(threadID: threadID)
            return
        }

        do {
            try await loadHistory(threadID: threadID, using: configuration)
            if streamTask == nil, !configuration.token.isEmpty {
                startStreaming(using: configuration)
            }
        } catch {
            errorMessage = error.localizedDescription
            composerNotice = ComposerNotice(message: "无法刷新最新会话记录。", tone: .error)
        }
    }

    func createThread(using configuration: GatewayConfiguration) async {
        currentConfiguration = configuration
        errorMessage = nil

        if configuration.isDemoMode {
            let thread = ThreadInfo(
                id: UUID(),
                state: "ready",
                turnCount: 0,
                createdAt: "刚刚",
                updatedAt: "刚刚",
                title: "新的演示会话",
                threadType: "conversation",
                channel: "preview"
            )
            threads.insert(thread, at: 0)
            selectedThread = thread
            turns = []
            pendingGate = nil
            resetComposerState()
            resetLiveState()
            composerNotice = ComposerNotice(message: "已创建新的演示会话。", tone: .info)
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            let thread = try await client.createThread()
            threads.insert(thread, at: 0)
            selectedThread = thread
            turns = []
            pendingGate = nil
            resetComposerState()
            resetLiveState()
        } catch {
            errorMessage = error.localizedDescription
            composerNotice = ComposerNotice(message: "无法在网关上创建新会话。", tone: .error)
        }
    }

    func send(using configuration: GatewayConfiguration) async {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        currentConfiguration = configuration
        errorMessage = nil
        composerNotice = nil
        pendingUserMessage = trimmed
        streamingResponseText = ""
        eventFeed = []
        streamState = .sending
        let draftAttachments = composerAttachments
        let imagePayloads = draftAttachments.map(\.payload)
        composerText = ""
        composerAttachments = []

        if configuration.isDemoMode {
            await sendDemoMessage(trimmed, attachments: draftAttachments)
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            let payload = SendMessageRequest(
                content: trimmed,
                threadID: selectedThread?.id.uuidString,
                timezone: TimeZone.current.identifier,
                images: imagePayloads
            )
            _ = try await client.sendMessage(payload)
        } catch {
            composerText = trimmed
            composerAttachments = draftAttachments
            errorMessage = error.localizedDescription
            streamState = .failed
            composerNotice = ComposerNotice(message: "无法发送当前草稿，请修复问题后重试。", tone: .error)
        }
    }

    func resolveGate(_ resolution: GateResolutionPayloadDTO, configuration: GatewayConfiguration) async {
        currentConfiguration = configuration
        guard let pendingGate else { return }

        if configuration.isDemoMode {
            self.pendingGate = nil
            switch resolution {
            case .approved:
                streamState = .idle
                composerNotice = ComposerNotice(message: "演示审批已通过，模拟运行已完成。", tone: .info)
            case .denied, .cancelled:
                streamState = .idle
                composerNotice = ComposerNotice(message: "演示审批流程已结束。", tone: .warning)
            case .credentialProvided:
                streamState = .idle
                composerNotice = ComposerNotice(message: "已接受演示凭证。", tone: .info)
            }
            eventFeed.insert(ChatEvent(type: "gate_resolved", threadID: pendingGate.threadID, requestID: pendingGate.requestID, message: nil, content: nil, name: nil, toolName: pendingGate.toolName, gateName: pendingGate.gateName, description: nil, parameters: nil, preview: nil, detail: nil, resolution: "approved", success: true, resumeKind: .null), at: 0)
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            try await client.resolveGate(requestID: pendingGate.requestID, threadID: pendingGate.threadID, resolution: resolution)
            self.pendingGate = nil
            composerNotice = nil
            streamState = .streaming
            scheduleHistoryRefresh()
        } catch {
            errorMessage = error.localizedDescription
            streamState = .failed
            composerNotice = ComposerNotice(message: "审批响应未成功发送到网关，请重试。", tone: .error)
        }
    }

    func stopStreaming(showNotice: Bool = true) {
        streamTask?.cancel()
        streamTask = nil
        streamConnectionID = UUID()
        if showNotice {
            composerNotice = ComposerNotice(message: "实时更新已停止；如果网关上的运行仍在继续，请下拉刷新。", tone: .warning)
        }
        streamState = pendingGate == nil ? .idle : .waitingForGate
    }

    func updateComposerAttachments(_ attachments: [ComposerAttachment]) {
        composerAttachments = attachments
        if attachments.isEmpty {
            if composerNotice?.tone == .info {
                composerNotice = nil
            }
        } else {
            composerNotice = ComposerNotice(message: "已准备好 \(attachments.count) 张图片，可随下一条消息一起发送。", tone: .info)
        }
    }

    private func loadHistory(threadID: UUID, using configuration: GatewayConfiguration) async throws {
        let client = GatewayClient(configuration: configuration)
        let history = try await client.history(threadID: threadID)
        turns = history.turns
        pendingGate = history.pendingGate
        pendingUserMessage = nil
        streamingResponseText = ""
        eventFeed = []
        streamState = history.pendingGate == nil ? .idle : .waitingForGate
        if history.pendingGate != nil {
            composerNotice = ComposerNotice(message: "需要审批后当前运行才能继续。", tone: .warning)
        } else if streamState != .failed {
            composerNotice = nil
        }
    }

    private func startStreaming(using configuration: GatewayConfiguration) {
        stopStreaming(showNotice: false)
        guard !configuration.token.isEmpty else { return }
        let token = configuration.token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? configuration.token
        guard let url = URL(string: "/api/chat/events?token=\(token)", relativeTo: configuration.baseURL) else { return }

        let sse = SSEClient()
        let connectionID = UUID()
        streamConnectionID = connectionID
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await envelope in sse.stream(url: url) {
                    guard self.streamConnectionID == connectionID else { return }
                    let data = Data(envelope.data.utf8)
                    guard let event = try? JSONDecoder.ironClaw.decode(ChatEvent.self, from: data) else {
                        continue
                    }
                    await self.handle(event: event)
                }
            } catch is CancellationError {
            } catch {
                guard self.streamConnectionID == connectionID else { return }
                await self.handleStreamFailure(error)
            }
        }
    }

    private func handleStreamFailure(_ error: Error) {
        errorMessage = error.localizedDescription
        composerNotice = ComposerNotice(message: "流式连接已断开，请刷新会话以恢复最新状态。", tone: .error)
        if streamState != .waitingForGate {
            streamState = .failed
        }
    }

    private func handle(event: ChatEvent) {
        guard eventAppliesToCurrentThread(event) else { return }

        eventFeed.insert(event, at: 0)
        if eventFeed.count > 40 {
            eventFeed = Array(eventFeed.prefix(40))
        }

        switch event.type {
        case "stream_chunk":
            composerNotice = nil
            streamState = .streaming
            streamingResponseText += event.content ?? ""
        case "thinking", "tool_started", "tool_result", "tool_completed":
            composerNotice = nil
            if streamState == .sending {
                streamState = .streaming
            }
        case "status":
            let statusMessage = (event.message ?? "").lowercased()
            if statusMessage == "awaiting approval" {
                composerNotice = ComposerNotice(message: "当前运行正在等待你的审批。", tone: .warning)
                streamState = .waitingForGate
                scheduleHistoryRefresh()
            } else if statusMessage == "done" {
                composerNotice = nil
                streamState = .idle
                if pendingUserMessage != nil || !streamingResponseText.isEmpty {
                    scheduleHistoryRefresh()
                }
            }
        case "response":
            if let content = event.content, !content.isEmpty {
                streamingResponseText = content
            }
            pendingGate = nil
            composerNotice = nil
            streamState = .idle
            scheduleHistoryRefresh()
        case "gate_required":
            if let requestID = event.requestID {
                pendingGate = PendingGateInfo(
                    requestID: requestID,
                    threadID: event.threadID ?? selectedThread?.id.uuidString ?? "",
                    gateName: event.gateName ?? "approval",
                    toolName: event.toolName ?? event.name ?? "Tool",
                    description: event.description ?? event.message ?? "需要审批",
                    parameters: event.parameters ?? "",
                    resumeKind: event.resumeKind ?? .null
                )
            }
            composerNotice = ComposerNotice(message: "需要审批后本次运行才能继续。", tone: .warning)
            pendingUserMessage = nil
            streamState = .waitingForGate
            scheduleHistoryRefresh()
        case "gate_resolved":
            pendingGate = nil
            composerNotice = (event.resolution ?? "").lowercased() == "approved"
                ? ComposerNotice(message: "审批已发送，等待运行恢复。", tone: .info)
                : nil
            streamState = (event.resolution ?? "").lowercased() == "approved" ? .streaming : .idle
            scheduleHistoryRefresh()
        case "error":
            errorMessage = event.primaryText ?? "未知网关错误"
            composerNotice = ComposerNotice(message: "网关为当前运行返回了错误。", tone: .error)
            streamState = .failed
        default:
            break
        }
    }

    private func eventAppliesToCurrentThread(_ event: ChatEvent) -> Bool {
        guard let threadID = event.threadID, !threadID.isEmpty else { return true }
        return threadID == selectedThread?.id.uuidString
    }

    private func scheduleHistoryRefresh() {
        guard !isHistoryRefreshScheduled, let configuration = currentConfiguration, selectedThread != nil else {
            return
        }

        isHistoryRefreshScheduled = true
        Task { [weak self] in
            guard let self else { return }
            await self.refreshHistory(using: configuration)
            await MainActor.run {
                self.isHistoryRefreshScheduled = false
            }
        }
    }

    private func selectedThread(from response: ThreadListResponse) -> ThreadInfo? {
        if let activeThreadID = response.activeThread {
            if response.assistantThread?.id == activeThreadID {
                return response.assistantThread
            }
            if let thread = response.threads.first(where: { $0.id == activeThreadID }) {
                return thread
            }
        }
        return response.assistantThread ?? response.threads.first
    }

    private func loadDemoHistory(threadID: UUID) async {
        turns = DemoContent.histories[threadID] ?? []
        pendingGate = DemoContent.pendingGates[threadID]
        pendingUserMessage = nil
        streamingResponseText = ""
        eventFeed = []
        streamState = pendingGate == nil ? .idle : .waitingForGate
        if pendingGate != nil {
            composerNotice = ComposerNotice(message: "需要审批后当前运行才能继续。", tone: .warning)
        } else if streamState != .failed {
            composerNotice = nil
        }
    }

    private func sendDemoMessage(_ message: String, attachments: [ComposerAttachment]) async {
        if selectedThread == nil {
            selectedThread = DemoContent.assistantThread
        }

        eventFeed = [
            ChatEvent(type: "thinking", threadID: selectedThread?.id.uuidString, requestID: nil, message: "正在检查演示数据", content: nil, name: nil, toolName: nil, gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: nil, resumeKind: nil),
            ChatEvent(type: "tool_started", threadID: selectedThread?.id.uuidString, requestID: nil, message: "正在准备原生预览", content: nil, name: nil, toolName: "demo.preview", gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: true, resumeKind: nil)
        ]
        streamState = .streaming

        let reply = DemoContent.reply(for: message, attachmentCount: attachments.count)
        for chunk in DemoContent.streamingChunks(for: reply) {
            streamingResponseText += chunk
        }

        if DemoContent.shouldRequireApproval(for: message) {
            pendingGate = PendingGateInfo(
                requestID: UUID().uuidString,
                threadID: selectedThread?.id.uuidString ?? "",
                gateName: "approval",
                toolName: "demo.preview",
                description: "请审批这个模拟的生产操作，以继续演示运行。",
                parameters: "mode=demo",
                resumeKind: .string("continue")
            )
            pendingUserMessage = nil
            streamState = .waitingForGate
            composerNotice = ComposerNotice(message: "演示模式正在等待你的审批。", tone: .warning)
            eventFeed.insert(ChatEvent(type: "gate_required", threadID: selectedThread?.id.uuidString, requestID: pendingGate?.requestID, message: "需要审批", content: nil, name: nil, toolName: "demo.preview", gateName: "approval", description: pendingGate?.description, parameters: pendingGate?.parameters, preview: nil, detail: nil, resolution: nil, success: nil, resumeKind: .string("continue")), at: 0)
            return
        }

        pendingGate = nil
        pendingUserMessage = nil
        streamState = .idle
        composerNotice = ComposerNotice(message: "演示回复已完成。", tone: .info)
        eventFeed.insert(ChatEvent(type: "response", threadID: selectedThread?.id.uuidString, requestID: nil, message: nil, content: reply, name: nil, toolName: nil, gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: true, resumeKind: nil), at: 0)

        let nextTurn = TurnInfo(
            turnNumber: (turns.last?.turnNumber ?? 0) + 1,
            userInput: message,
            response: reply,
            state: "completed",
            startedAt: "刚刚",
            completedAt: "刚刚",
            toolCalls: [
                ToolCallInfo(
                    name: attachments.isEmpty ? "demo.preview" : "demo.vision",
                    hasResult: true,
                    hasError: false,
                    resultPreview: attachments.isEmpty ? "已生成纯文本预览回复。" : "已生成包含 \(attachments.count) 张附加图片的多模态预览。",
                    error: nil,
                    rationale: nil
                )
            ],
            generatedImages: DemoContent.generatedImages(for: message),
            narrative: configurationNarrative(for: attachments)
        )
        turns.append(nextTurn)
        updateSelectedThreadMetadata(turnCount: turns.count, state: "ready")
        streamingResponseText = ""
    }

    private func configurationNarrative(for attachments: [ComposerAttachment]) -> String? {
        attachments.isEmpty ? "此回复基于内置演示数据集生成。" : "此回复基于内置演示数据集和附加的预览图片生成。"
    }

    private func updateSelectedThreadMetadata(turnCount: Int, state: String) {
        guard let selectedThread else { return }
        let updatedThread = ThreadInfo(
            id: selectedThread.id,
            state: state,
            turnCount: turnCount,
            createdAt: selectedThread.createdAt,
            updatedAt: "刚刚",
            title: selectedThread.title,
            threadType: selectedThread.threadType,
            channel: selectedThread.channel
        )
        self.selectedThread = updatedThread
        if assistantThread?.id == updatedThread.id {
            assistantThread = updatedThread
        }
        if let index = threads.firstIndex(where: { $0.id == updatedThread.id }) {
            threads[index] = updatedThread
        }
    }

    private func resetLiveState() {
        pendingUserMessage = nil
        streamingResponseText = ""
        eventFeed = []
        streamState = .idle
    }

    private func resetComposerState() {
        composerText = ""
        composerAttachments = []
        composerNotice = nil
    }
}
