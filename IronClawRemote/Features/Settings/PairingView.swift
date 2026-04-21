import SwiftUI

struct PairingView: View {
    @Environment(AppState.self) private var appState
    @State private var channel = "web"
    @State private var requests: [PairingRequestInfoDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var busyCode: String?

    var body: some View {
        List {
            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.success)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(ICColor.danger)
                }
            }

            Section("通道") {
                TextField("通道名称", text: $channel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("查询配对请求") {
                    Task { await load() }
                }
                .disabled(channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("待处理请求") {
                if isLoading && requests.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if requests.isEmpty {
                    Text("当前没有待处理的配对请求")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                } else {
                    ForEach(requests) { req in
                        VStack(alignment: .leading, spacing: ICSpacing.xs) {
                            HStack {
                                Text(req.code)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(req.createdAt)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                            }

                            Text("发送者: \(req.senderID)")
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)

                            if let meta = req.meta, meta != .null {
                                Text(meta.compactText)
                                    .font(.caption2)
                                    .foregroundStyle(ICColor.textSecondary)
                                    .lineLimit(2)
                            }

                            HStack {
                                Button("批准") {
                                    Task { await approve(req) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(busyCode == req.code)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("配对审批")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        let ch = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ch.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if appState.gatewayConfiguration.isDemoMode {
            requests = []
            return
        }

        do {
            let response = try await appState.gatewayClient.pairingRequests(channel: ch)
            requests = response.requests
        } catch {
            requests = []
            errorMessage = error.localizedDescription
        }
    }

    private func approve(_ req: PairingRequestInfoDTO) async {
        let ch = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ch.isEmpty else { return }
        busyCode = req.code
        defer { busyCode = nil }

        do {
            let response = try await appState.gatewayClient.approvePairing(channel: ch, code: req.code)
            actionMessage = response.message
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
