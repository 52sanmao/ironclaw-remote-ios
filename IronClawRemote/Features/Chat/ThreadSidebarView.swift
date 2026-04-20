import SwiftUI

struct ThreadSidebarView: View {
    let assistantThread: ThreadInfo?
    let threads: [ThreadInfo]
    let selectedThread: ThreadInfo?
    let onSelect: (ThreadInfo) -> Void
    let onNewThread: () -> Void

    var body: some View {
        List(selection: .constant(selectedThread?.id)) {
            if let assistantThread {
                Section("助手") {
                    threadRow(assistantThread, roleLabel: "助手")
                }
            }
            Section {
                Button(action: onNewThread) {
                    Label("新建会话", systemImage: "plus.circle.fill")
                }
            }
            Section("会话列表") {
                ForEach(threads) { thread in
                    threadRow(thread)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func threadRow(_ thread: ThreadInfo, roleLabel: String? = nil) -> some View {
        let isSelected = selectedThread?.id == thread.id

        Button(action: { onSelect(thread) }) {
            VStack(alignment: .leading, spacing: ICSpacing.xs) {
                HStack(alignment: .top, spacing: ICSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.title ?? fallbackTitle(for: thread))
                            .font(.headline)
                            .foregroundStyle(ICColor.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: ICSpacing.xs) {
                            if let roleLabel {
                                badge(roleLabel, color: ICColor.accent)
                            }
                            badge(localizedStateTitle(for: thread.state), color: statusColor(for: thread.state))
                            badge("\(thread.turnCount) 轮", color: ICColor.textSecondary)
                        }
                    }
                    Spacer(minLength: ICSpacing.sm)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ICColor.accent)
                    }
                }

                HStack(spacing: ICSpacing.sm) {
                    Label(thread.updatedAt, systemImage: "clock")
                    if let channel = thread.channel, !channel.isEmpty {
                        Label(channel, systemImage: "number")
                    }
                }
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
            }
            .padding(.vertical, ICSpacing.xs)
            .padding(.horizontal, ICSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous)
                    .fill(isSelected ? ICColor.accent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fallbackTitle(for thread: ThreadInfo) -> String {
        if let threadType = thread.threadType, !threadType.isEmpty {
            switch threadType.lowercased() {
            case "assistant":
                return "助手"
            case "conversation":
                return "会话"
            default:
                return threadType
            }
        }
        return "会话"
    }

    private func localizedStateTitle(for state: String) -> String {
        switch state.lowercased() {
        case "running", "active", "streaming":
            return "运行中"
        case "waiting", "queued", "paused", "pending":
            return "等待中"
        case "failed", "error":
            return "失败"
        case "ready", "completed", "success", "succeeded":
            return "就绪"
        default:
            return state
        }
    }

    private func statusColor(for state: String) -> Color {
        switch state.lowercased() {
        case "running", "active", "streaming":
            return ICColor.success
        case "waiting", "queued", "paused":
            return ICColor.warning
        case "failed", "error":
            return ICColor.danger
        default:
            return ICColor.textSecondary
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
