import Foundation
import SwiftUI

@MainActor
@Observable
final class WorkspaceViewModel {
    var entries: [MemoryTreeEntry] = []
    var directoryEntries: [MemoryListEntry] = []
    var selectedFile: MemoryReadResponse?
    var selectedEntryPath: String?
    var selectedEntryIsDirectory = false
    var currentDirectoryPath = ""
    var searchQuery = ""
    var searchResults: [MemoryListEntry] = []
    var draftContent = ""
    var newFileName = ""
    var newFileContent = ""
    var loadErrorMessage: String?
    var searchErrorMessage: String?
    var previewErrorMessage: String?
    var infoMessage: String?
    var actionMessage: String?
    var isLoading = false
    var isSearching = false
    var isOpeningFile = false
    var isSaving = false
    var isCreatingFile = false
    var hasSearched = false

    private var demoFiles: [String: MemoryReadResponse] = [:]

    var canGoUp: Bool {
        !currentDirectoryPath.isEmpty
    }

    func load(using configuration: GatewayConfiguration) async {
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }

        if configuration.isDemoMode {
            entries = sortTreeEntries(allDemoEntries())
            await loadDirectory(path: currentDirectoryPath, configuration: configuration)
            await restoreSelection(using: configuration)
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            async let treeRequest = client.memoryTree()
            async let directoryRequest = client.memoryList(path: currentDirectoryPath)
            let fetchedTree = try await treeRequest
            let fetchedDirectory = try await directoryRequest
            entries = sortTreeEntries(fetchedTree.entries)
            directoryEntries = sortDirectoryEntries(fetchedDirectory.entries)
            await restoreSelection(using: configuration)
        } catch {
            entries = []
            directoryEntries = []
            selectedFile = nil
            selectedEntryPath = nil
            selectedEntryIsDirectory = false
            loadErrorMessage = error.localizedDescription
            previewErrorMessage = nil
            infoMessage = nil
        }
    }

    func goToRoot(using configuration: GatewayConfiguration) async {
        await loadDirectory(path: "", configuration: configuration)
    }

    func goToParent(using configuration: GatewayConfiguration) async {
        guard canGoUp else { return }
        let parent = currentDirectoryPath.split(separator: "/").dropLast().joined(separator: "/")
        await loadDirectory(path: parent, configuration: configuration)
    }

    func openDirectoryEntry(_ entry: MemoryListEntry, configuration: GatewayConfiguration) async {
        selectedEntryPath = entry.path
        selectedEntryIsDirectory = entry.isDir
        if entry.isDir {
            await loadDirectory(path: entry.path, configuration: configuration)
        } else {
            await openFile(at: entry.path, configuration: configuration)
        }
    }

    func selectSearchResult(_ entry: MemoryListEntry, configuration: GatewayConfiguration) async {
        selectedEntryPath = entry.path
        selectedEntryIsDirectory = entry.isDir
        guard !entry.isDir else {
            await loadDirectory(path: entry.path, configuration: configuration)
            return
        }
        await openFile(at: entry.path, configuration: configuration)
    }

    func search(using configuration: GatewayConfiguration) async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchErrorMessage = nil

        guard !query.isEmpty else {
            hasSearched = false
            searchResults = []
            return
        }

        hasSearched = true
        isSearching = true
        defer { isSearching = false }

        if configuration.isDemoMode {
            searchResults = sortSearchResults(DemoContent.searchResults(for: query) + demoSearchResults(for: query))
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            searchResults = sortSearchResults(try await client.searchMemory(query: query))
        } catch {
            searchResults = []
            searchErrorMessage = error.localizedDescription
        }
    }

    func updateDraft(_ value: String) {
        draftContent = value
    }

    func revertDraft() {
        draftContent = selectedFile?.content ?? ""
    }

    func saveSelectedFile(using configuration: GatewayConfiguration) async {
        guard let path = selectedFile?.path else { return }
        isSaving = true
        actionMessage = nil
        previewErrorMessage = nil
        defer { isSaving = false }

        if configuration.isDemoMode {
            let updated = MemoryReadResponse(path: path, content: draftContent, updatedAt: "刚刚")
            demoFiles[path] = updated
            selectedFile = updated
            actionMessage = "已在演示模式中更新预览。"
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            try await client.writeMemory(path: path, content: draftContent)
            selectedFile = try await client.readMemory(path: path)
            draftContent = selectedFile?.content ?? draftContent
            actionMessage = "文件已写回网关。"
            let refreshedDirectory = try await client.memoryList(path: currentDirectoryPath)
            directoryEntries = sortDirectoryEntries(refreshedDirectory.entries)
        } catch {
            previewErrorMessage = error.localizedDescription
        }
    }

    func createFile(using configuration: GatewayConfiguration) async {
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let path = currentDirectoryPath.isEmpty ? name : "\(currentDirectoryPath)/\(name)"
        isCreatingFile = true
        actionMessage = nil
        previewErrorMessage = nil
        defer { isCreatingFile = false }

        if configuration.isDemoMode {
            let created = MemoryReadResponse(path: path, content: newFileContent, updatedAt: "刚刚")
            demoFiles[path] = created
            entries = sortTreeEntries(allDemoEntries())
            newFileName = ""
            newFileContent = ""
            actionMessage = "已在演示模式中创建文件。"
            await loadDirectory(path: currentDirectoryPath, configuration: configuration)
            await openFile(at: path, configuration: configuration)
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            try await client.writeMemory(path: path, content: newFileContent)
            newFileName = ""
            newFileContent = ""
            actionMessage = "新文件已创建。"
            let fetchedTree = try await client.memoryTree()
            entries = sortTreeEntries(fetchedTree.entries)
            await loadDirectory(path: currentDirectoryPath, configuration: configuration)
            await openFile(at: path, configuration: configuration)
        } catch {
            previewErrorMessage = error.localizedDescription
        }
    }

    private func loadDirectory(path: String, configuration: GatewayConfiguration) async {
        currentDirectoryPath = normalizedPath(path)
        selectedEntryPath = currentDirectoryPath.isEmpty ? nil : currentDirectoryPath
        selectedEntryIsDirectory = true
        selectedFile = nil
        draftContent = ""
        actionMessage = nil
        previewErrorMessage = nil
        infoMessage = directoryMessage(for: currentDirectoryPath)

        if configuration.isDemoMode {
            directoryEntries = sortDirectoryEntries(demoDirectoryEntries(at: currentDirectoryPath))
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            let response = try await client.memoryList(path: currentDirectoryPath)
            directoryEntries = sortDirectoryEntries(response.entries)
        } catch {
            directoryEntries = []
            previewErrorMessage = error.localizedDescription
        }
    }

    private func restoreSelection(using configuration: GatewayConfiguration) async {
        if let selectedEntryPath {
            if let matchingFile = selectedFile, matchingFile.path == selectedEntryPath {
                draftContent = matchingFile.content
                return
            }

            if let matchingFile = entries.first(where: { $0.path == selectedEntryPath && !$0.isDir }) {
                await openFile(at: matchingFile.path, configuration: configuration)
                return
            }
        }

        if let firstFile = directoryEntries.first(where: { !$0.isDir }) {
            await openFile(at: firstFile.path, configuration: configuration)
        } else {
            selectedFile = nil
            draftContent = ""
            infoMessage = directoryMessage(for: currentDirectoryPath)
        }
    }

    private func openFile(at path: String, configuration: GatewayConfiguration) async {
        isOpeningFile = true
        selectedEntryPath = path
        selectedEntryIsDirectory = false
        selectedFile = nil
        draftContent = ""
        previewErrorMessage = nil
        infoMessage = nil
        defer { isOpeningFile = false }

        if configuration.isDemoMode {
            if let file = demoFile(at: path) {
                selectedFile = file
                draftContent = file.content
            } else {
                previewErrorMessage = "未找到演示文件。"
            }
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            let file = try await client.readMemory(path: path)
            selectedFile = file
            draftContent = file.content
        } catch {
            previewErrorMessage = error.localizedDescription
        }
    }

    private func directoryMessage(for path: String) -> String {
        if path.isEmpty {
            return "当前位于工作区根目录。请选择文件以预览或编辑。"
        }
        return "当前位于 \(path)。请选择文件以预览或编辑。"
    }

    private func normalizedPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func demoFile(at path: String) -> MemoryReadResponse? {
        demoFiles[path] ?? DemoContent.memoryFiles[path]
    }

    private func allDemoEntries() -> [MemoryTreeEntry] {
        var merged = Dictionary(uniqueKeysWithValues: DemoContent.memoryEntries.map { ($0.path, $0) })
        for path in demoFiles.keys {
            let components = path.split(separator: "/").map(String.init)
            for index in 0..<max(components.count - 1, 0) {
                let directoryPath = components[0...index].joined(separator: "/")
                merged[directoryPath] = MemoryTreeEntry(path: directoryPath, isDir: true)
            }
            merged[path] = MemoryTreeEntry(path: path, isDir: false)
        }
        return Array(merged.values)
    }

    private func demoDirectoryEntries(at path: String) -> [MemoryListEntry] {
        let normalized = normalizedPath(path)
        let prefix = normalized.isEmpty ? "" : normalized + "/"
        return allDemoEntries().compactMap { entry in
            guard entry.path != normalized else { return nil }
            guard entry.path.hasPrefix(prefix) else { return nil }
            let remainder = String(entry.path.dropFirst(prefix.count))
            guard !remainder.isEmpty, !remainder.contains("/") else { return nil }
            return MemoryListEntry(
                name: remainder,
                path: entry.path,
                isDir: entry.isDir,
                updatedAt: demoFile(at: entry.path)?.updatedAt
            )
        }
    }

    private func demoSearchResults(for query: String) -> [MemoryListEntry] {
        let normalizedQuery = query.lowercased()
        return demoFiles.values.compactMap { file in
            guard file.path.lowercased().contains(normalizedQuery) || file.content.lowercased().contains(normalizedQuery) else {
                return nil
            }
            return MemoryListEntry(
                name: file.path.split(separator: "/").last.map(String.init) ?? file.path,
                path: file.path,
                isDir: false,
                updatedAt: file.updatedAt
            )
        }
    }

    private func sortTreeEntries(_ entries: [MemoryTreeEntry]) -> [MemoryTreeEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDir != rhs.isDir {
                return lhs.isDir && !rhs.isDir
            }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private func sortDirectoryEntries(_ entries: [MemoryListEntry]) -> [MemoryListEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDir != rhs.isDir {
                return lhs.isDir && !rhs.isDir
            }
            let lhsKey = lhs.name.isEmpty ? lhs.path : lhs.name
            let rhsKey = rhs.name.isEmpty ? rhs.path : rhs.name
            return lhsKey.localizedStandardCompare(rhsKey) == .orderedAscending
        }
    }

    private func sortSearchResults(_ entries: [MemoryListEntry]) -> [MemoryListEntry] {
        sortDirectoryEntries(Array(Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) }).values))
    }
}
