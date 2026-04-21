import SwiftUI

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WorkspaceViewModel()
    @State private var isPresentingCreateSheet = false

    private var canSearch: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching
    }

    private var canSaveDraft: Bool {
        guard let selectedFile = viewModel.selectedFile else { return false }
        return !viewModel.isSaving && viewModel.draftContent != selectedFile.content
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("工作区")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            isPresentingCreateSheet = true
                        } label: {
                            Label("新建", systemImage: "square.and.pencil")
                        }
                        .disabled(viewModel.isLoading)

                        Button {
                            Task { await viewModel.load(using: appState.gatewayConfiguration) }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
        } detail: {
            detailContent
                .navigationTitle(detailTitle)
                .task {
                    await viewModel.load(using: appState.gatewayConfiguration)
                }
                .refreshable {
                    await viewModel.load(using: appState.gatewayConfiguration)
                }
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            createFileSheet
        }
    }

    private var detailTitle: String {
        if let selectedFile = viewModel.selectedFile {
            return selectedFile.path.split(separator: "/").last.map(String.init) ?? "预览"
        }
        if viewModel.selectedEntryIsDirectory {
            return viewModel.currentDirectoryPath.isEmpty ? "根目录" : "目录"
        }
        return "预览"
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
            } else {
                List {
                    Section {
                        directoryHeader
                    }
                    .listRowInsets(EdgeInsets(top: ICSpacing.sm, leading: ICSpacing.md, bottom: ICSpacing.sm, trailing: ICSpacing.md))
                    .listRowBackground(Color.clear)

                    if !viewModel.directoryEntries.isEmpty {
                        Section("当前目录") {
                            ForEach(viewModel.directoryEntries) { entry in
                                Button {
                                    Task { await viewModel.openDirectoryEntry(entry, configuration: appState.gatewayConfiguration) }
                                } label: {
                                    WorkspaceListEntryRow(
                                        entry: entry,
                                        isSelected: viewModel.selectedEntryPath == entry.path
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if !viewModel.isLoading {
                        Section("当前目录") {
                            ContentUnavailableView(
                                "目录为空",
                                systemImage: "folder",
                                description: Text("这里还没有文件或子目录。")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ICSpacing.md)
                        }
                    }

                    if !viewModel.searchResults.isEmpty || viewModel.hasSearched || viewModel.isSearching || viewModel.searchErrorMessage != nil {
                        Section("搜索") {
                            searchSidebarContent
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(ICColor.background)
            }
        }
    }

    private var directoryHeader: some View {
        VStack(alignment: .leading, spacing: ICSpacing.sm) {
            HStack(spacing: ICSpacing.sm) {
                Button {
                    Task { await viewModel.goToRoot(using: appState.gatewayConfiguration) }
                } label: {
                    Label("根目录", systemImage: "house")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.currentDirectoryPath.isEmpty || viewModel.isLoading)

                Button {
                    Task { await viewModel.goToParent(using: appState.gatewayConfiguration) }
                } label: {
                    Label("上一级", systemImage: "arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canGoUp || viewModel.isLoading)
            }

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text("当前位置")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ICColor.textSecondary)
                Text(viewModel.currentDirectoryPath.isEmpty ? "/" : viewModel.currentDirectoryPath)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ICColor.textPrimary)
                    .textSelection(.enabled)
            }

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
                .buttonStyle(.borderedProminent)
                .disabled(!canSearch)
            }
        }
    }

    @ViewBuilder
    private var searchSidebarContent: some View {
        if viewModel.isSearching {
            Label("正在搜索…", systemImage: "magnifyingglass")
                .foregroundStyle(ICColor.textSecondary)
        } else if let searchErrorMessage = viewModel.searchErrorMessage {
            Text(searchErrorMessage)
                .font(.caption)
                .foregroundStyle(ICColor.danger)
        } else if !viewModel.searchResults.isEmpty {
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
        } else if viewModel.hasSearched {
            Text("没有匹配结果")
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                if let actionMessage = viewModel.actionMessage {
                    WorkspaceStatusCard(
                        title: "操作已完成",
                        message: actionMessage,
                        systemImage: "checkmark.circle.fill",
                        tint: ICColor.success
                    )
                }

                if let previewErrorMessage = viewModel.previewErrorMessage {
                    WorkspaceStatusCard(
                        title: "操作失败",
                        message: previewErrorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: ICColor.danger
                    )
                }

                if viewModel.selectedEntryIsDirectory {
                    directoryDetailCard
                } else if let selectedFile = viewModel.selectedFile {
                    fileEditorCard(for: selectedFile)
                } else if let infoMessage = viewModel.infoMessage {
                    ContentUnavailableView(
                        "选择文件",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(infoMessage)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, ICSpacing.xl)
                } else {
                    ContentUnavailableView("选择记忆文件", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding(.top, ICSpacing.xl)
                }
            }
            .padding(ICSpacing.md)
        }
        .background(ICColor.background)
    }

    private var directoryDetailCard: some View {
        VStack(alignment: .leading, spacing: ICSpacing.md) {
            Label(viewModel.currentDirectoryPath.isEmpty ? "根目录" : viewModel.currentDirectoryPath, systemImage: "folder.fill")
                .font(.headline)
                .foregroundStyle(ICColor.textPrimary)

            if let infoMessage = viewModel.infoMessage {
                Text(infoMessage)
                    .font(.subheadline)
                    .foregroundStyle(ICColor.textSecondary)
            }

            if viewModel.directoryEntries.isEmpty {
                ContentUnavailableView(
                    "目录为空",
                    systemImage: "folder",
                    description: Text("可以在这里新建文件，或返回上一级继续浏览。")
                )
            } else {
                VStack(alignment: .leading, spacing: ICSpacing.sm) {
                    Text("包含内容")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ICColor.textPrimary)
                    ForEach(viewModel.directoryEntries) { entry in
                        Button {
                            Task { await viewModel.openDirectoryEntry(entry, configuration: appState.gatewayConfiguration) }
                        } label: {
                            WorkspaceSearchResultRow(
                                entry: entry,
                                isSelected: viewModel.selectedEntryPath == entry.path
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }

    private func fileEditorCard(for selectedFile: MemoryReadResponse) -> some View {
        VStack(alignment: .leading, spacing: ICSpacing.md) {
            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(selectedFile.path)
                    .font(.headline)
                    .foregroundStyle(ICColor.textPrimary)
                    .textSelection(.enabled)
                if let updatedAt = selectedFile.updatedAt, !updatedAt.isEmpty {
                    Label(updatedAt, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            TextEditor(text: Binding(
                get: { viewModel.draftContent },
                set: { viewModel.updateDraft($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(ICColor.textPrimary)
            .frame(minHeight: 320)
            .padding(ICSpacing.sm)
            .background(ICColor.background)
            .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))

            HStack(spacing: ICSpacing.sm) {
                Button("还原") {
                    viewModel.revertDraft()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving || viewModel.draftContent == selectedFile.content)

                Button(viewModel.isSaving ? "保存中…" : "保存") {
                    Task { await viewModel.saveSelectedFile(using: appState.gatewayConfiguration) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSaveDraft)
            }
        }
        .padding(ICSpacing.md)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }

    private var createFileSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ICSpacing.md) {
                    TextField("文件名", text: Binding(
                        get: { viewModel.newFileName },
                        set: { viewModel.newFileName = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Text("将在 \(viewModel.currentDirectoryPath.isEmpty ? "/" : viewModel.currentDirectoryPath) 下创建")
                        .font(.caption)
                        .foregroundStyle(ICColor.textSecondary)

                    TextEditor(text: Binding(
                        get: { viewModel.newFileContent },
                        set: { viewModel.newFileContent = $0 }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
                    .padding(ICSpacing.sm)
                    .background(ICColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
                }
                .padding(ICSpacing.md)
            }
            .background(ICColor.background)
            .navigationTitle("新建文件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        isPresentingCreateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isCreatingFile ? "创建中…" : "创建") {
                        Task {
                            let previousName = viewModel.newFileName
                            await viewModel.createFile(using: appState.gatewayConfiguration)
                            if !previousName.isEmpty, viewModel.newFileName.isEmpty {
                                isPresentingCreateSheet = false
                            }
                        }
                    }
                    .disabled(viewModel.newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isCreatingFile)
                }
            }
        }
    }
}

private struct WorkspaceListEntryRow: View {
    let entry: MemoryListEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: ICSpacing.sm) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.text")
                .foregroundStyle(entry.isDir ? ICColor.warning : ICColor.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                Text(entry.name.isEmpty ? entry.path : entry.name)
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
