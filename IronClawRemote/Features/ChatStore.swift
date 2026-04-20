import Foundation
import Observation

@Observable
final class ChatStore {
    var threads: [ThreadInfo] = []
    var selectedThreadID: UUID?
    var messages: [ChatMessage] = []
    var composerText = ""
    var isLoadingThreads = false
    var isSending = false
    var streamState: ChatStreamState = .idle
    var pendingGate: PendingGateInfo?
    var lastErrorMessage: String?

    var selectedThread: ThreadInfo? {
        guard let selectedThreadID else { return threads.first }
        return threads.first(where: { $0.id == selectedThreadID }) ?? threads.first
    }

    @MainActor
    func load(using client: GatewayClient) async {
        isLoadingThreads = true
        lastErrorMessage = nil
        defer { isLoadingThreads = false }
        do {
            let response = try await client.threads()
            threads = response.assistantThread.map { [$0] + response.threads } ?? response.threads
            selectedThreadID = response.activeThread ?? threads.first?.id
            if let selectedThreadID {
                try await loadHistory(threadID: selectedThreadID, using: client)
            } else {
                messages = []
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadHistory(threadID: UUID, using client: GatewayClient) async throws {
        lastErrorMessage = nil
        let history = try await client.history(threadID: threadID)
        selectedThreadID = threadID
        pendingGate = history.pendingGate
        messages = history.turns.flatMap(ChatMessage.messages)
    }

    @MainActor
    func createThread(using client: GatewayClient) async {
        lastErrorMessage = nil
        do {
            let thread = try await client.createThread()
            threads.insert(thread, at: 0)
            selectedThreadID = thread.id
            messages = []
            pendingGate = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func send(using client: GatewayClient) async {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        streamState = .sending
        lastErrorMessage = nil
        let userMessage = ChatMessage.user(trimmed)
        messages.append(userMessage)
        composerText = ""
        do {
            let payload = SendMessageRequest(
                content: trimmed,
                threadID: selectedThreadID?.uuidString,
                timezone: TimeZone.current.identifier,
                images: []
            )
            _ = try await client.sendMessage(payload)
            streamState = .streaming
            if let selectedThreadID {
                try await loadHistory(threadID: selectedThreadID, using: client)
            } else {
                await load(using: client)
            }
            streamState = .idle
        } catch {
            streamState = .failed
            lastErrorMessage = error.localizedDescription
            messages.append(.assistant("Failed to send message. \(error.localizedDescription)"))
        }
        isSending = false
    }
}

enum ChatStreamState: String {
    case idle
    case sending
    case streaming
    case waitingForGate
    case failed
}

struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
        case event(String)
    }

    let id: UUID
    let role: Role
    let text: String
    let detail: String?

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), role: .user, text: text, detail: nil)
    }

    static func assistant(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), role: .assistant, text: text, detail: nil)
    }

    static func event(type: String, text: String, detail: String? = nil) -> ChatMessage {
        ChatMessage(id: UUID(), role: .event(type), text: text, detail: detail)
    }

    static func messages(from turn: TurnInfo) -> [ChatMessage] {
        var result: [ChatMessage] = [.user(turn.userInput)]
        if let narrative = turn.narrative, !narrative.isEmpty {
            result.append(.event(type: "thinking", text: narrative))
        }
        result.append(contentsOf: turn.toolCalls.map {
            .event(type: $0.name, text: $0.name, detail: $0.resultPreview ?? $0.error ?? $0.rationale)
        })
        if let response = turn.response, !response.isEmpty {
            result.append(.assistant(response))
        }
        return result
    }

    static func messages(_ turn: TurnInfo) -> [ChatMessage] {
        messages(from: turn)
    }
}
