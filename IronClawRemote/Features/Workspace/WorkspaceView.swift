import SwiftUI

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WorkspaceViewModel()

    private var directoryEntries: [MemoryTreeEntry] {
        viewModel.entries.filter(\.isDir)
    }

    private var fileEntries: [MemoryTreeEntry] {
        viewModel.entries.filter { !$0.isDir }
    }

    private var canSearch: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("工作区")
        } detail: {
            detailContent
                .navigationTitle("预览")
                .task {
                    await viewModel.load(using: appState.gatewayConfiguration)
                }
                .refreshable {
                    await viewModel.load(using: appState.gatewayConfiguration)
                }
        }
    }

    private var sidebarContent: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ContentUnavailableView("正在加载工作区…", systemImage: "folder")
            } else if let loadErrorMessage = viewModel.loadErrorMessage, viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "无法加载工作区",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorMessage)
                )
            } else if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "暂无记忆文件",
                    systemImage: "folder",
                    description: Text("网关返回的工作区树为空。")
                )
            } else {
                List {
                    if !directoryEntries.isEmpty {
                        Section("目录") {
                            ForEach(directoryEntries) { entry in
                                entryButton(for: entry)
                            }
                        }
                    }

                    if !fileEntries.isEmpty {
                        Section("文件") {
                            ForEach(fileEntries) { entry in
                                entryButton(for: entry)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                HStack(spacing: ICSpacing.sm) {
                    TextField("搜索工作区", text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.searchQuery = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        if canSearch {
                            Task { await viewModel.search(using: appState.gatewayConfiguration) }
                        }
                    }

                    Button(viewModel.isSearching ? "搜索中…" : "搜索") {
                        Task { await viewModel.search(using: appState.gatewayConfiguration) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSearch)
                }

                searchSection
                previewSection
            }
            .padding(ICSpacing.md)
        }
        .background(ICColor.background)
    }

    @ViewBuilder
    private var searchSection: some View {
        if viewModel.isSearching {
            WorkspaceStatusCard(
                title: "正在搜索工作区…",
                message: "正在查找匹配的记忆文件和文件夹。",
                systemImage: "magnifyingglass",
                tint: ICColor.textSecondary
            )
        } else if let searchErrorMessage = viewModel.searchErrorMessage {
            WorkspaceStatusCard(
                title: "搜索失败",
                message: searchErrorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: ICColor.danger
            )
        } else if !viewModel.searchResults.isEmpty {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                HStack {
                    Text("搜索结果")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.searchResults.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ICColor.textSecondary)
                }

                ForEach(viewModel.searchResults) { result in
                    Button {
                        Task { await viewModel.selectSearchResult(result, configuration: appState.gatewayConfiguration) }
                    } label: {
                        WorkspaceSearchResultRow(
                            entry: result,
                            isSelected: viewModel.selectedEntryPath == result.path
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if viewModel.hasSearched {
            ContentUnavailableView(
                "没有搜索结果",
                systemImage: "magnifyingglass",
                description: Text("请尝试其他名称或更短的关键词。")
            )
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if viewModel.isOpeningFile {
            ContentUnavailableView("正在加载预览…", systemImage: "doc.text")
        } else if let previewErrorMessage = viewModel.previewErrorMessage {
            WorkspaceStatusCard(
                title: "无法打开文件",
                message: previewErrorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: ICColor.danger
            )
        } else if viewModel.selectedEntryIsDirectory, let selectedEntryPath = viewModel.selectedEntryPath {
            ContentUnavailableView(
                "已选中目录",
                systemImage: "folder.badge.questionmark",
                description: Text("\(selectedEntryPath) 是一个目录。请选择文件以预览其内容。")
            )
        } else if let selectedFile = viewModel.selectedFile {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                Text(selectedFile.path)
                    .font(.headline)
                    .foregroundStyle(ICColor.textPrimary)
                if let updatedAt = selectedFile.updatedAt, !updatedAt.isEmpty {
                    Label(updatedAt, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
                Text(selectedFile.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(ICColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(ICSpacing.md)
            .background(ICColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        } else if let infoMessage = viewModel.infoMessage {
            ContentUnavailableView(
                "选择文件",
                systemImage: "doc.text.magnifyingglass",
                description: Text(infoMessage)
            )
        } else {
            ContentUnavailableView("选择记忆文件", systemImage: "doc.text.magnifyingglass")
        }
    }

    private func entryButton(for entry: MemoryTreeEntry) -> some View {
        Button {
            Task { await viewModel.select(entry, configuration: appState.gatewayConfiguration) }
        } label: {
            WorkspaceEntryRow(entry: entry, isSelected: viewModel.selectedEntryPath == entry.path)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceEntryRow: View {
    let entry: MemoryTreeEntry
    let isSelected: Bool

    private var title: String {
        entry.path.split(separator: "/").last.map(String.init) ?? entry.path
    }

    var body: some View {
        HStack(spacing: ICSpacing.sm) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.text")
                .foregroundStyle(entry.isDir ? ICColor.warning : ICColor.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ICColor.textPrimary)
                    .lineLimit(1)
                Text(entry.path)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: entry.isDir ? "folder.badge.questionmark" : "checkmark.circle.fill")
                    .foregroundStyle(entry.isDir ? ICColor.warning : ICColor.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkspaceSearchResultRow: View {
    let entry: MemoryListEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: ICSpacing.sm) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.text.magnifyingglass")
                .foregroundStyle(entry.isDir ? ICColor.warning : ICColor.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(entry.name.isEmpty ? entry.path : entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ICColor.textPrimary)
                Text(entry.path)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
                if let updatedAt = entry.updatedAt, !updatedAt.isEmpty {
                    Label(updatedAt, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.up.forward.square")
                .foregroundStyle(isSelected ? ICColor.accent : ICColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ICSpacing.sm)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }
}

private struct WorkspaceStatusCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: ICSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ICColor.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(ICColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }
}
