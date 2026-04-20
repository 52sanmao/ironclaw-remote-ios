import Foundation
import SwiftUI
import UIKit

private enum MessageListAnchor {
    static let bottom = "message-list-bottom"
}

struct MessageListView: View {
    let turns: [TurnInfo]
    let pendingUserMessage: String?
    let streamingResponseText: String
    let streamState: ChatStreamState
    let eventFeed: [ChatEvent]
    let pendingGate: PendingGateInfo?
    let isLoading: Bool
    let hasSelectedThread: Bool
    let resolveGate: (GateResolutionPayloadDTO) -> Void

    private var showsLiveAssistantCard: Bool {
        !streamingResponseText.isEmpty ||
        streamState == .sending ||
        streamState == .streaming ||
        streamState == .waitingForGate ||
        streamState == .failed
    }

    private var hasVisibleConversationContent: Bool {
        !turns.isEmpty ||
        !(pendingUserMessage?.isEmpty ?? true) ||
        !streamingResponseText.isEmpty ||
        pendingGate != nil ||
        !eventFeed.isEmpty ||
        streamState != .idle
    }

    private var emptyState: MessageListEmptyState? {
        guard !hasVisibleConversationContent else { return nil }
        if isLoading {
            return .loading
        }
        if !hasSelectedThread {
            return .unselected
        }
        return .ready
    }

    private var scrollSignature: String {
        let lastTurnSignature: String
        if let lastTurn = turns.last {
            lastTurnSignature = [
                "id:\(lastTurn.id)",
                "response:\(lastTurn.response?.count ?? 0)",
                "tools:\(lastTurn.toolCalls.count)",
                "images:\(lastTurn.generatedImages.count)",
                "narrative:\(lastTurn.narrative?.count ?? 0)",
                "state:\(lastTurn.state)"
            ].joined(separator: ",")
        } else {
            lastTurnSignature = "none"
        }

        let pendingCount = pendingUserMessage?.count ?? 0
        let gateID = pendingGate?.id ?? "none"
        return [
            "turns:\(turns.count)",
            "last:\(lastTurnSignature)",
            "stream:\(streamingResponseText.count)",
            "pending:\(pendingCount)",
            "events:\(eventFeed.count)",
            "gate:\(gateID)",
            "state:\(streamState.rawValue)"
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ICSpacing.md) {
                    if let emptyState {
                        EmptyConversationCard(state: emptyState)
                    } else {
                        if let pendingGate {
                            PendingGateCard(gate: pendingGate, resolveGate: resolveGate)
                        }

                        ForEach(turns) { turn in
                            TurnCardView(turn: turn)
                        }

                        if let pendingUserMessage, !pendingUserMessage.isEmpty {
                            PendingUserCard(text: pendingUserMessage)
                        }

                        if showsLiveAssistantCard {
                            LiveAssistantCard(text: streamingResponseText, state: streamState)
                        }

                        if !eventFeed.isEmpty {
                            LiveActivityPanel(events: eventFeed)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(MessageListAnchor.bottom)
                }
                .padding(ICSpacing.md)
            }
            .onAppear {
                scheduleScrollToBottom(using: proxy, animated: false)
            }
            .onChange(of: scrollSignature) { _, _ in
                scheduleScrollToBottom(using: proxy)
            }
        }
    }

    private func scheduleScrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        Task { @MainActor in
            scrollToBottom(using: proxy, animated: animated)
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            proxy.scrollTo(MessageListAnchor.bottom, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), scrollAction)
        } else {
            scrollAction()
        }
    }
}

private enum MessageListEmptyState {
    case loading
    case unselected
    case ready

    var title: String {
        switch self {
        case .loading:
            return "Loading conversation…"
        case .unselected:
            return "No thread selected"
        case .ready:
            return "No messages yet"
        }
    }

    var systemImage: String {
        switch self {
        case .loading:
            return "ellipsis.message"
        case .unselected:
            return "sidebar.left"
        case .ready:
            return "bubble.left.and.text.bubble.right"
        }
    }

    var description: String {
        switch self {
        case .loading:
            return "Syncing the latest messages from your IronClaw gateway."
        case .unselected:
            return "Pick a thread from the sidebar or create a new one to start chatting."
        case .ready:
            return "Start a conversation from the composer below."
        }
    }
}

private struct EmptyConversationCard: View {
    let state: MessageListEmptyState

    var body: some View {
        ContentUnavailableView(
            state.title,
            systemImage: state.systemImage,
            description: Text(state.description)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, ICSpacing.md)
    }
}

private struct TurnCardView: View {
    let turn: TurnInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            UserBubble(text: turn.userInput)

            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                if let response = turn.response, !response.isEmpty {
                    Text(response)
                        .font(.body)
                }
                if let narrative = turn.narrative, !narrative.isEmpty {
                    Text(narrative)
                        .font(.footnote)
                        .foregroundStyle(ICColor.textSecondary)
                }
                ForEach(turn.toolCalls) { tool in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(tool.name, systemImage: tool.hasError ? "exclamationmark.triangle.fill" : "hammer.fill")
                            .font(.subheadline.bold())
                        if let resultPreview = tool.resultPreview {
                            Text(resultPreview)
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                        if let error = tool.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(ICColor.danger)
                        }
                    }
                    .padding(.top, 4)
                }
                if !turn.generatedImages.isEmpty {
                    GeneratedImageSection(images: turn.generatedImages)
                }
            }
            .icCard()
        }
    }
}

private struct PendingUserCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Sending…")
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
            UserBubble(text: text)
        }
    }
}

private struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .padding(ICSpacing.md)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(ICColor.accent.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }
}

private struct LiveAssistantCard: View {
    let text: String
    let state: ChatStreamState

    private var statusText: String {
        switch state {
        case .sending:
            return "Waiting for IronClaw…"
        case .streaming:
            return "Streaming response"
        case .waitingForGate:
            return "Awaiting approval"
        case .failed:
            return "Stream failed"
        case .idle:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack(spacing: ICSpacing.xs) {
                if state == .sending || state == .streaming {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .icCard()
    }
}

private struct LiveActivityPanel: View {
    let events: [ChatEvent]

    private var visibleEvents: [ChatEvent] {
        Array(events.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Live Activity")
                    .font(.headline)
                Spacer(minLength: 0)
                Text("\(visibleEvents.count) updates")
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }

            ForEach(visibleEvents.indices, id: \.self) { index in
                LiveActivityRow(event: visibleEvents[index])
                if index < visibleEvents.count - 1 {
                    Divider()
                }
            }
        }
        .icCard()
    }
}

private struct LiveActivityRow: View {
    let event: ChatEvent

    var body: some View {
        HStack(alignment: .top, spacing: ICSpacing.sm) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ICColor.textPrimary)
                if let content = event.primaryText, !content.isEmpty {
                    Text(content)
                        .font(.caption2)
                        .foregroundStyle(ICColor.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var iconName: String {
        switch event.type {
        case "thinking":
            return "brain.head.profile"
        case "tool_started", "tool_result", "tool_completed":
            return event.success == false ? "exclamationmark.triangle.fill" : "hammer.fill"
        case "gate_required", "gate_resolved":
            return "lock.shield"
        case "error":
            return "xmark.octagon.fill"
        case "status":
            return "info.circle"
        default:
            return "sparkles"
        }
    }

    private var iconColor: Color {
        switch event.type {
        case "error":
            return ICColor.danger
        case "gate_required":
            return ICColor.warning
        default:
            return ICColor.textSecondary
        }
    }
}

private struct GeneratedImageSection: View {
    let images: [GeneratedImageInfo]

    private let columns = [
        GridItem(.flexible(), spacing: ICSpacing.sm),
        GridItem(.flexible(), spacing: ICSpacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Label("Generated Images", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.bold())
                .foregroundStyle(ICColor.textPrimary)

            LazyVGrid(columns: columns, spacing: ICSpacing.sm) {
                ForEach(images) { image in
                    GeneratedImageTile(image: image)
                }
            }
        }
    }
}

private struct GeneratedImageTile: View {
    let image: GeneratedImageInfo

    private var decodedImage: Image? {
        guard let data = decodedData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var decodedData: Data? {
        guard let dataURL = image.dataURL?.trimmingCharacters(in: .whitespacesAndNewlines), !dataURL.isEmpty else {
            return nil
        }
        let encodedPayload: String
        if let commaIndex = dataURL.firstIndex(of: ",") {
            encodedPayload = String(dataURL[dataURL.index(after: commaIndex)...])
        } else {
            encodedPayload = dataURL
        }
        return Data(base64Encoded: encodedPayload, options: [.ignoreUnknownCharacters])
    }

    private var remoteURL: URL? {
        guard let path = image.path?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: path),
              url.scheme != nil else {
            return nil
        }
        return url
    }

    private var pathCaption: String? {
        guard let path = image.path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        return path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.xs) {
            imageSurface

            if let pathCaption {
                Text(pathCaption)
                    .font(.caption2)
                    .foregroundStyle(ICColor.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(ICColor.background)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var imageSurface: some View {
        if let decodedImage {
            decodedImage
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))
        } else if let remoteURL {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(ICColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))
                case .failure:
                    placeholderSurface
                @unknown default:
                    placeholderSurface
                }
            }
        } else {
            placeholderSurface
        }
    }

    private var placeholderSurface: some View {
        VStack(spacing: ICSpacing.xs) {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(ICColor.textSecondary)
            Text("Preview unavailable")
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))
    }
}

private struct PendingGateCard: View {
    let gate: PendingGateInfo
    let resolveGate: (GateResolutionPayloadDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            Label("Approval Required", systemImage: "lock.shield")
                .font(.headline)
            Text(gate.description)
            if !gate.parameters.isEmpty {
                Text(gate.parameters)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }
            HStack {
                Button("Approve") { resolveGate(.approved(always: false)) }
                    .buttonStyle(.borderedProminent)
                Button("Deny", role: .destructive) { resolveGate(.denied) }
                    .buttonStyle(.bordered)
                Button("Cancel") { resolveGate(.cancelled) }
                    .buttonStyle(.bordered)
            }
        }
        .icCard()
    }
}
