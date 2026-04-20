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
                .navigationTitle("Workspace")
        } detail: {
            detailContent
                .navigationTitle("Preview")
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
                ContentUnavailableView("Loading workspace…", systemImage: "folder")
            } else if let loadErrorMessage = viewModel.loadErrorMessage, viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "Couldn’t load workspace",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorMessage)
                )
            } else if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "No memory files",
                    systemImage: "folder",
                    description: Text("The gateway returned an empty workspace tree.")
                )
            } else {
                List {
                    if !directoryEntries.isEmpty {
                        Section("Directories") {
                            ForEach(directoryEntries) { entry in
                                entryButton(for: entry)
                            }
                        }
                    }

                    if !fileEntries.isEmpty {
                        Section("Files") {
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
                    TextField("Search workspace", text: Binding(
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

                    Button(viewModel.isSearching ? "Searching…" : "Search") {
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
                title: "Searching workspace…",
                message: "Looking for matching memory files and folders.",
                systemImage: "magnifyingglass",
                tint: ICColor.textSecondary
            )
        } else if let searchErrorMessage = viewModel.searchErrorMessage {
            WorkspaceStatusCard(
                title: "Search failed",
                message: searchErrorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: ICColor.danger
            )
        } else if !viewModel.searchResults.isEmpty {
            VStack(alignment: .leading, spacing: ICSpacing.sm) {
                HStack {
                    Text("Search Results")
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
                "No search results",
                systemImage: "magnifyingglass",
                description: Text("Try another name or a shorter keyword.")
            )
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if viewModel.isOpeningFile {
            ContentUnavailableView("Loading preview…", systemImage: "doc.text")
        } else if let previewErrorMessage = viewModel.previewErrorMessage {
            WorkspaceStatusCard(
                title: "Couldn’t open file",
                message: previewErrorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: ICColor.danger
            )
        } else if viewModel.selectedEntryIsDirectory, let selectedEntryPath = viewModel.selectedEntryPath {
            ContentUnavailableView(
                "Directory selected",
                systemImage: "folder.badge.questionmark",
                description: Text("\(selectedEntryPath) is a directory. Select a file to preview its contents.")
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
                "Select a file",
                systemImage: "doc.text.magnifyingglass",
                description: Text(infoMessage)
            )
        } else {
            ContentUnavailableView("Select a memory file", systemImage: "doc.text.magnifyingglass")
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
