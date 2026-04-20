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
            composerNotice = ComposerNotice(message: "Couldn’t load chat threads from the gateway.", tone: .error)
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
            composerNotice = ComposerNotice(message: "Couldn’t refresh the latest thread history.", tone: .error)
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
                createdAt: "Just now",
                updatedAt: "Just now",
                title: "New Demo Thread",
                threadType: "conversation",
                channel: "preview"
            )
            threads.insert(thread, at: 0)
            selectedThread = thread
            turns = []
            pendingGate = nil
            resetComposerState()
            resetLiveState()
            composerNotice = ComposerNotice(message: "Created a new demo thread.", tone: .info)
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
            composerNotice = ComposerNotice(message: "Couldn’t create a new thread on the gateway.", tone: .error)
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
            composerNotice = ComposerNotice(message: "Couldn’t send the current draft. Fix the issue and try again.", tone: .error)
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
                composerNotice = ComposerNotice(message: "Demo approval granted. The simulated run is complete.", tone: .info)
            case .denied, .cancelled:
                streamState = .idle
                composerNotice = ComposerNotice(message: "Demo approval flow closed.", tone: .warning)
            case .credentialProvided:
                streamState = .idle
                composerNotice = ComposerNotice(message: "Demo credential accepted.", tone: .info)
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
            composerNotice = ComposerNotice(message: "Approval response didn’t reach the gateway. Try again.", tone: .error)
        }
    }

    func stopStreaming(showNotice: Bool = true) {
        streamTask?.cancel()
        streamTask = nil
        streamConnectionID = UUID()
        if showNotice {
            composerNotice = ComposerNotice(message: "Live updates stopped. Pull to refresh if the run continued on the gateway.", tone: .warning)
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
            composerNotice = ComposerNotice(message: "\(attachments.count) image\(attachments.count == 1 ? "" : "s") ready to send with your next message.", tone: .info)
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
            composerNotice = ComposerNotice(message: "Approval is required before the active run can continue.", tone: .warning)
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
        composerNotice = ComposerNotice(message: "Stream disconnected. Refresh the thread to recover the latest state.", tone: .error)
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
                composerNotice = ComposerNotice(message: "The run is waiting for your approval.", tone: .warning)
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
                    description: event.description ?? event.message ?? "Approval required",
                    parameters: event.parameters ?? "",
                    resumeKind: event.resumeKind ?? .null
                )
            }
            composerNotice = ComposerNotice(message: "Approval is required before the run can continue.", tone: .warning)
            pendingUserMessage = nil
            streamState = .waitingForGate
            scheduleHistoryRefresh()
        case "gate_resolved":
            pendingGate = nil
            composerNotice = (event.resolution ?? "").lowercased() == "approved"
                ? ComposerNotice(message: "Approval sent. Waiting for the run to resume.", tone: .info)
                : nil
            streamState = (event.resolution ?? "").lowercased() == "approved" ? .streaming : .idle
            scheduleHistoryRefresh()
        case "error":
            errorMessage = event.primaryText ?? "Unknown gateway error"
            composerNotice = ComposerNotice(message: "Gateway returned an error for the current run.", tone: .error)
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
            composerNotice = ComposerNotice(message: "Approval is required before the active run can continue.", tone: .warning)
        } else if streamState != .failed {
            composerNotice = nil
        }
    }

    private func sendDemoMessage(_ message: String, attachments: [ComposerAttachment]) async {
        if selectedThread == nil {
            selectedThread = DemoContent.assistantThread
        }

        eventFeed = [
            ChatEvent(type: "thinking", threadID: selectedThread?.id.uuidString, requestID: nil, message: "Inspecting demo data", content: nil, name: nil, toolName: nil, gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: nil, resumeKind: nil),
            ChatEvent(type: "tool_started", threadID: selectedThread?.id.uuidString, requestID: nil, message: "Preparing native preview", content: nil, name: nil, toolName: "demo.preview", gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: true, resumeKind: nil)
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
                description: "Approve this simulated production action to continue the demo run.",
                parameters: "mode=demo",
                resumeKind: .string("continue")
            )
            pendingUserMessage = nil
            streamState = .waitingForGate
            composerNotice = ComposerNotice(message: "Demo mode is waiting for your approval.", tone: .warning)
            eventFeed.insert(ChatEvent(type: "gate_required", threadID: selectedThread?.id.uuidString, requestID: pendingGate?.requestID, message: "Approval required", content: nil, name: nil, toolName: "demo.preview", gateName: "approval", description: pendingGate?.description, parameters: pendingGate?.parameters, preview: nil, detail: nil, resolution: nil, success: nil, resumeKind: .string("continue")), at: 0)
            return
        }

        pendingGate = nil
        pendingUserMessage = nil
        streamState = .idle
        composerNotice = ComposerNotice(message: "Demo reply completed.", tone: .info)
        eventFeed.insert(ChatEvent(type: "response", threadID: selectedThread?.id.uuidString, requestID: nil, message: nil, content: reply, name: nil, toolName: nil, gateName: nil, description: nil, parameters: nil, preview: nil, detail: nil, resolution: nil, success: true, resumeKind: nil), at: 0)

        let nextTurn = TurnInfo(
            turnNumber: (turns.last?.turnNumber ?? 0) + 1,
            userInput: message,
            response: reply,
            state: "completed",
            startedAt: "Just now",
            completedAt: "Just now",
            toolCalls: [
                ToolCallInfo(
                    name: attachments.isEmpty ? "demo.preview" : "demo.vision",
                    hasResult: true,
                    hasError: false,
                    resultPreview: attachments.isEmpty ? "Rendered a text-only preview response." : "Rendered a multimodal preview with \(attachments.count) attached image\(attachments.count == 1 ? "" : "s").",
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
        attachments.isEmpty ? "This response was generated from the built-in demo dataset." : "This response used the built-in demo dataset plus the attached preview images."
    }

    private func updateSelectedThreadMetadata(turnCount: Int, state: String) {
        guard let selectedThread else { return }
        let updatedThread = ThreadInfo(
            id: selectedThread.id,
            state: state,
            turnCount: turnCount,
            createdAt: selectedThread.createdAt,
            updatedAt: "Just now",
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
