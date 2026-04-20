import SwiftUI

struct ChatHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChatViewModel()
    @State private var showingConnectionSheet = false

    var body: some View {
        NavigationSplitView {
            ThreadSidebarView(
                assistantThread: viewModel.assistantThread,
                threads: viewModel.threads,
                selectedThread: viewModel.selectedThread,
                onSelect: { thread in
                    Task { await viewModel.selectThread(thread, configuration: appState.gatewayConfiguration) }
                },
                onNewThread: {
                    Task { await viewModel.createThread(using: appState.gatewayConfiguration) }
                }
            )
            .navigationTitle("会话")
        } detail: {
            VStack(spacing: 0) {
                ChatHeaderView(
                    configuration: appState.gatewayConfiguration,
                    status: appState.session.connectionStatus,
                    streamState: viewModel.streamState,
                    openConnection: { showingConnectionSheet = true }
                )
                Divider()
                MessageListView(
                    turns: viewModel.turns,
                    pendingUserMessage: viewModel.pendingUserMessage,
                    streamingResponseText: viewModel.streamingResponseText,
                    streamState: viewModel.streamState,
                    eventFeed: viewModel.eventFeed,
                    pendingGate: viewModel.pendingGate,
                    isLoading: viewModel.isLoading,
                    hasSelectedThread: viewModel.selectedThread != nil
                ) { resolution in
                    Task { await viewModel.resolveGate(resolution, configuration: appState.gatewayConfiguration) }
                }
                ComposerView(
                    text: Binding(
                        get: { viewModel.composerText },
                        set: { viewModel.composerText = $0 }
                    ),
                    attachments: viewModel.composerAttachments,
                    notice: viewModel.composerNotice,
                    streamState: viewModel.streamState,
                    onAttachmentsChanged: { attachments in
                        viewModel.updateComposerAttachments(attachments)
                    },
                    onSend: {
                        Task { await viewModel.send(using: appState.gatewayConfiguration) }
                    },
                    onStop: {
                        viewModel.stopStreaming()
                    }
                )
            }
            .background(ICColor.background)
            .navigationTitle(viewModel.selectedThread?.title ?? "IronClaw")
            .task {
                await viewModel.load(using: appState.gatewayConfiguration)
                await appState.refreshProfile()
            }
            .refreshable {
                await viewModel.refreshHistory(using: appState.gatewayConfiguration)
                await appState.refreshProfile()
            }
            .sheet(isPresented: $showingConnectionSheet) {
                GatewayConnectionView()
            }
            .alert("连接错误", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
