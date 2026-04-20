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
                    Text(status.rawValue.capitalized)
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
            return "Sending"
        case .streaming:
            return "Streaming"
        case .waitingForGate:
            return "Approval"
        case .failed:
            return "Error"
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
