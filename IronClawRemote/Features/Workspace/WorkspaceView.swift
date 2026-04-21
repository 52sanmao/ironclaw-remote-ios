import SwiftUI

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WorkspaceViewModel()
    @State private var isPresentingCreateSheet = false

    private var canSearch: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching
    }

    var body: some View {
        List {
            if let actionMessage = viewModel.actionMessage {
                Section {
                    HStack(spacing: ICSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ICColor.success)
                        Text(actionMessage)
                            .font(.caption)
                            .foregroundStyle(ICColor.success)
                        Spacer()
                    }
                    .padding(ICSpacing.sm)
                    .background(ICColor.success.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let previewErrorMessage = viewModel.previewErrorMessage {
                Section {
                    HStack(spacing: ICSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ICColor.danger)
                        Text(previewErrorMessage)
                            .font(.caption)
                            .foregroundStyle(ICColor.danger)
                        Spacer()
                    }
                    .padding(ICSpacing.sm)
                    .background(ICColor.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
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
                .padding(.vertical, ICSpacing.sm)
            }
            .listRowInsets(EdgeInsets(top: ICSpacing.sm, leading: ICSpacing.md, bottom: ICSpacing.sm, trailing: ICSpacing.md))
            .listRowBackground(Color.clear)

            if !viewModel.searchResults.isEmpty || viewModel.hasSearched || viewModel.isSearching || viewModel.searchErrorMessage != nil {
                Section("搜索结果") {
                    searchResultsContent
                }
            }

            Section("目录内容") {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        "目录为空",
                        systemImage: "folder",
                        description: Text("这里还没有文件或子目录。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ICSpacing.md)
                } else {
                    ForEach(viewModel.directoryEntries) { entry in
                        if entry.isDir {
                            Button {
                                Task { await viewModel.openDirectoryEntry(entry, configuration: appState.gatewayConfiguration) }
                            } label: {
                                WorkspaceListEntryRow(
                                    entry: entry,
                                    isSelected: viewModel.selectedEntryPath == entry.path
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                WorkspaceFileEditorView(
                                    path: entry.path,
                                    configuration: appState.gatewayConfiguration
                                )
                            } label: {
                                WorkspaceListEntryRow(
                                    entry: entry,
                                    isSelected: viewModel.selectedEntryPath == entry.path
                                )
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ICColor.background)
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
        .sheet(isPresented: $isPresentingCreateSheet) {
            createFileSheet
        }
        .task {
            await viewModel.load(using: appState.gatewayConfiguration)
        }
        .refreshable {
            await viewModel.load(using: appState.gatewayConfiguration)
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if viewModel.isSearching {
            Label("正在搜索…", systemImage: "magnifyingglass")
                .foregroundStyle(ICColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, ICSpacing.sm)
        } else if let searchErrorMessage = viewModel.searchErrorMessage {
            HStack(spacing: ICSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ICColor.danger)
                Text(searchErrorMessage)
                    .font(.caption)
                    .foregroundStyle(ICColor.danger)
                Spacer()
            }
            .padding(ICSpacing.sm)
            .background(ICColor.danger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
        } else if !viewModel.searchResults.isEmpty {
            ForEach(viewModel.searchResults) { result in
                if result.isDir {
                    Button {
                        Task { await viewModel.selectSearchResult(result, configuration: appState.gatewayConfiguration) }
                    } label: {
                        WorkspaceSearchResultRow(
                            entry: result,
                            isSelected: viewModel.selectedEntryPath == result.path
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        WorkspaceFileEditorView(
                            path: result.path,
                            configuration: appState.gatewayConfiguration
                        )
                    } label: {
                        WorkspaceSearchResultRow(
                            entry: result,
                            isSelected: viewModel.selectedEntryPath == result.path
                        )
                    }
                }
            }
        } else if viewModel.hasSearched {
            Text("没有匹配结果")
                .font(.caption)
                .foregroundStyle(ICColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, ICSpacing.sm)
        }
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

struct WorkspaceFileEditorView: View {
    let path: String
    let configuration: GatewayConfiguration

    @State private var draftContent: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var fileInfo: MemoryReadResponse?
    @State private var isLoading = false

    private var canSave: Bool {
        !isSaving && draftContent != (fileInfo?.content ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ICSpacing.md) {
                if let actionMessage {
                    HStack(spacing: ICSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ICColor.success)
                        Text(actionMessage)
                            .font(.caption)
                            .foregroundStyle(ICColor.success)
                        Spacer()
                    }
                    .padding(ICSpacing.md)
                    .background(ICColor.success.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
                }

                if let errorMessage {
                    HStack(spacing: ICSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ICColor.danger)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(ICColor.danger)
                        Spacer()
                    }
                    .padding(ICSpacing.md)
                    .background(ICColor.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
                }

                VStack(alignment: .leading, spacing: ICSpacing.md) {
                    VStack(alignment: .leading, spacing: ICSpacing.xxs) {
                        Text(fileInfo?.path ?? path)
                            .font(.headline)
                            .foregroundStyle(ICColor.textPrimary)
                            .textSelection(.enabled)
                        if let updatedAt = fileInfo?.updatedAt, !updatedAt.isEmpty {
                            Label(updatedAt, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(ICColor.textSecondary)
                        }
                    }

                    TextEditor(text: $draftContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(ICColor.textPrimary)
                        .frame(minHeight: 400)
                        .padding(ICSpacing.sm)
                        .background(ICColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))

                    HStack(spacing: ICSpacing.sm) {
                        Button("还原") {
                            draftContent = fileInfo?.content ?? content
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving || draftContent == (fileInfo?.content ?? content))

                        Button(isSaving ? "保存中…" : "保存") {
                            Task { await save() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
                .padding(ICSpacing.md)
                .background(ICColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
            }
            .padding(ICSpacing.md)
        }
        .background(ICColor.background)
        .navigationTitle(path.split(separator: "/").last.map(String.init) ?? "文件")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || isSaving)
            }
        }
        .task {
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if configuration.isDemoMode {
            fileInfo = MemoryReadResponse(path: path, content: draftContent.isEmpty ? "演示内容" : draftContent, updatedAt: nil)
            if draftContent.isEmpty {
                draftContent = fileInfo?.content ?? ""
            }
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            fileInfo = try await client.readMemory(path: path)
            draftContent = fileInfo?.content ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        if configuration.isDemoMode {
            actionMessage = "演示模式：未实际保存"
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            _ = try await client.writeMemory(path: path, content: draftContent)
            actionMessage = "已保存"
            await reload()
        } catch {
            errorMessage = error.localizedDescription
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
