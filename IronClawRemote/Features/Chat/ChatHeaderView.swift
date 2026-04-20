import SwiftUI

struct ChatHeaderView: View {
    let configuration: GatewayConfiguration
    let status: ConnectionStatus
    let streamState: ChatStreamState
    let openConnection: () -> Void

    var body: some View {
        HStack(spacing: ICSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name)
                    .font(.headline)
                HStack(spacing: ICSpacing.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(connectionStatusTitle)
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                    if let badgeText {
                        Text(badgeText)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeColor.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Button(action: openConnection) {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
            }
        }
        .padding(ICSpacing.md)
        .background(.ultraThinMaterial)
    }

    private var connectionStatusTitle: String {
        switch status {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .degraded:
            return "异常"
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected: ICColor.success
        case .connecting: ICColor.warning
        case .degraded: ICColor.warning
        case .disconnected: ICColor.danger
        }
    }

    private var badgeText: String? {
        switch streamState {
        case .idle:
            return nil
        case .sending:
            return "发送中"
        case .streaming:
            return "生成中"
        case .waitingForGate:
            return "待审批"
        case .failed:
            return "错误"
        }
    }

    private var badgeColor: Color {
        switch streamState {
        case .waitingForGate:
            return ICColor.warning
        case .failed:
            return ICColor.danger
        default:
            return ICColor.accent
        }
    }
}
